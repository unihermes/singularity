// Minimal persistent relay for the ALT+Tab switcher's IPC calls.
//
// alt-tab.sh needs to reach Quickshell's IPC target "alttab" once per Tab
// press. Doing that with the `qs` CLI works, but `qs` is the same monolithic
// binary as the shell itself -- it links Widgets/Quick/Qml/Gui/DBus/OpenGL
// on top of Core/Network, and the dynamic linker pays for all of that on
// every single invocation even though `ipc call` only ever touches Core and
// Network. Measured on this machine that's ~45ms of pure process-spawn
// overhead, which is enough on its own to lose a fast ALT+Tab tap-release
// against the switcher's keyboard grab.
//
// This relay stays running for the session and listens on its own much
// cheaper local socket for short commands (fed by `socat`, itself a small
// non-Qt binary) to forward to Quickshell's ipc.sock. It reconnects to
// Quickshell fresh for every command rather than holding one connection
// open across all of them: Quickshell's own IpcServerConnection closes
// itself right after handling a call (IpcServerConnection::onReadyRead in
// io/ipccomm.cpp, the `deleteLater()` after both transactions commit) --
// matching how `qs ipc call` only ever makes one-shot connections too. That
// reconnect is still just a local Unix socket connect from a process that's
// already running with Qt loaded, nowhere near the cost this file exists to
// avoid, which is starting the `qs` *process* itself. Nothing here talks to
// Quickshell over any *public*, version-stable interface -- there isn't one
// for this. It mirrors the private wire format Quickshell's own client
// (src/ipc/ipc.hpp, src/ipc/ipccommand.hpp, src/io/ipccomm.hpp in the
// quickshell-git source) uses internally: a std::variant tag byte followed
// by the chosen alternative's fields, written with QDataStream's own
// default (de)serialization for QString/QVector<QString> rather than any
// hand-rolled byte encoding -- so it can only drift if Quickshell's struct
// *shapes* change, not from an encoding mismatch, since both sides are the
// same Qt writing the same types the same way. Still: this is a private
// implementation detail of a `-git` package with no compatibility promise,
// and a future Quickshell update could silently change it out from under
// this file. If alt-tab stops responding after a quickshell update, this is
// the first place to check.
//
// So it checks itself. Until it has found the bar's instance (at startup,
// and again whenever that instance goes away), it sends every live
// Quickshell instance a `ping` call -- the one function on the "alttab"
// target with a return value -- through the same hand-built encoding every
// real command uses, and looks for the reply string in whatever comes back.
// That doesn't depend on the reply's own layout: if the request encoding has
// drifted, Quickshell can't decode it, never calls ping, and the string never
// appears. The instance that answers is also the one commands go to, so a
// second Quickshell (a test config, `qs -p` on something else) can't steal
// them. If no reachable instance answers for three rounds running -- long
// enough that a shell still loading its config isn't mistaken for it -- that
// is logged to ~/.cache/alttab-relay.log and raised as a desktop
// notification, instead of alt-tab just quietly doing nothing.
//
// Deliberately fire-and-forget: every "alttab" IPC function this relays
// (tab/prev/commit/cancel) returns void, and Quickshell executes a command
// before it ever tries to write a response back -- so there's nothing worth
// waiting to read, and skipping that wait is exactly the latency this
// exists to cut.
//
// Built entirely on QObject::connect to Qt's own signals (QLocalServer's
// newConnection, QLocalSocket's disconnected) with plain lambdas, and a real
// running event loop (app.exec()) -- not, as an earlier version of this file
// was, on a hand-rolled loop of blocking wait*() calls with no event loop
// running at all. That version looked like it worked in isolated one-off
// tests but silently dropped commands under any real repeated use: with
// nothing ever pumping Qt's event loop, a flush() had nothing driving it to
// completion once it couldn't write everything synchronously in one go, so
// a command could be sent and simply never actually leave the process.
// None of that needs solving by hand -- it is exactly what Qt's
// asynchronous, signal-driven model and a running event loop already do
// correctly. Using lambdas as slots on Qt's own signals needs no
// Q_OBJECT/moc of our own, so this still builds as one file with plain g++.

#include <QBuffer>
#include <QCoreApplication>
#include <QDataStream>
#include <QProcess>
#include <QTimer>
#include <QDir>
#include <QLocalServer>
#include <QLocalSocket>
#include <QString>
#include <QVector>
#include <QDebug>

#include <fcntl.h>
#include <unistd.h>
#include <sys/file.h>

namespace {

// Mirrors qs::io::ipc::comm::StringCallCommand (ipccomm.hpp): target
// function name, and its arguments as strings -- Quickshell's own IPC
// functions take/return only string-shaped values over this protocol,
// which is exactly what alt-tab.sh already sends (plain text and JSON
// handed through as a string).
struct StringCallCommand {
	QString target;
	QString function;
	QVector<QString> arguments;
};

QDataStream& operator<<(QDataStream& s, const StringCallCommand& c) {
	return s << c.target << c.function << c.arguments;
}

// Index of StringCallCommand within qs::ipc::IpcCommand's std::variant
// (ipccommand.hpp): monostate, IpcKillCommand, QueryMetadataCommand,
// StringCallCommand, SignalListenCommand, StringPropReadCommand.
constexpr quint8 kStringCallCommandIndex = 3;

QString xdgRuntimeDir() {
	auto dir = qEnvironmentVariable("XDG_RUNTIME_DIR");
	if (dir.isEmpty()) dir = QString("/run/user/%1").arg(getuid());
	return dir;
}

// Finds the live Quickshell instances for this user by the same mechanism
// Quickshell's own instance lock does (QsPaths::checkLock in
// core/paths.cpp): each instance directory under quickshell's `by-id`
// holds an `instance.lock` file that the live process holds an flock-style
// fcntl write lock on for as long as it runs. No lock held means the
// directory is a leftover from a process that has since exited.
QStringList findLiveIpcSockets() {
	QDir byId(xdgRuntimeDir() + "/quickshell/by-id");
	const auto entries = byId.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
	QStringList live;

	for (const auto& entry : entries) {
		auto lockPath = byId.filePath(entry) + "/instance.lock";
		auto fd = open(lockPath.toLocal8Bit().constData(), O_RDONLY);
		if (fd < 0) continue;

		struct flock lock {};
		lock.l_type = F_WRLCK;
		lock.l_whence = SEEK_SET;
		fcntl(fd, F_GETLK, &lock);
		close(fd);

		if (lock.l_type != F_UNLCK) live.push_back(byId.filePath(entry) + "/ipc.sock");
	}

	return live;
}

// The bytes QDataStream writes for a QString, minus its length prefix:
// what the ping reply's string looks like on the wire, whatever surrounds it.
QByteArray wireString(const QString& text) {
	QByteArray bytes;
	QBuffer buffer(&bytes);
	buffer.open(QIODevice::WriteOnly);
	QDataStream stream(&buffer);
	stream << text;
	return bytes.mid(4);
}

// "ok", "no" (connected, but no reply string), or "unreachable".
QString selfTest(const QString& sockPath) {
	QLocalSocket sock;
	sock.connectToServer(sockPath);
	if (!sock.waitForConnected(500)) return "unreachable";

	QDataStream stream(&sock);
	stream << kStringCallCommandIndex;
	stream << StringCallCommand { .target = "alttab", .function = "ping", .arguments = {} };
	sock.flush();

	// Quickshell hangs up once it has answered; read until then.
	QByteArray reply;
	while (sock.waitForReadyRead(1000)) reply += sock.readAll();
	reply += sock.readAll();

	return reply.contains(wireString("singularity-relay-pong")) ? "ok" : "no";
}

} // namespace

int main(int argc, char** argv) {
	QCoreApplication app(argc, argv);

	auto relaySockPath = xdgRuntimeDir() + "/singularity-alttab-relay.sock";
	QLocalServer::removeServer(relaySockPath);

	// Parented to `app` rather than stack/local objects: everything here
	// lives for the process's whole lifetime, and the lambdas below close
	// over these pointers, so they need stable addresses rather than
	// anything that could be a dangling stack reference by the time a
	// signal fires later.
	auto* server = new QLocalServer(&app);
	if (!server->listen(relaySockPath)) {
		qCritical() << "alttab-relay: failed to listen on" << relaySockPath;
		return 1;
	}

	auto* qsConn = new QLocalSocket(&app);
	auto* qsStream = new QDataStream(qsConn);

	// Connects fresh on (almost) every call, since Quickshell hangs up
	// after each one anyway -- see the file comment. The state() check
	// still matters despite that: it's what makes this relay launch-order
	// independent of quickshell (see hyprland.lua) and self-healing across
	// a quickshell restart mid-session, by re-running the instance lookup
	// whenever the last-known connection turns out to be down instead of
	// only ever trying once at startup.
	//
	// Still a blocking wait here (not another connect()+signal), but that's
	// fine: it runs inside a request that's already being handled from
	// within the running event loop, not as the entire program's control
	// flow the way every wait in the old design was.
	// the instance that answered the self-test's ping (see below), or "" --
	// before one has, the first live instance, as this always did
	auto* shellSock = new QString();

	auto ensureConnected = [=]() -> bool {
		if (qsConn->state() == QLocalSocket::ConnectedState) return true;

		auto sockPath = *shellSock;
		if (sockPath.isEmpty()) {
			auto live = findLiveIpcSockets();
			if (live.isEmpty()) return false;
			sockPath = live.first();
		}

		qsConn->connectToServer(sockPath);
		return qsConn->waitForConnected(200);
	};

	QObject::connect(server, &QLocalServer::newConnection, [=]() {
		while (auto* client = server->nextPendingConnection()) {
			// The whole message in, nothing out -- see the file comment on
			// why no response is worth reading. Collected up to
			// disconnection rather than up to the first newline:
			// `hyprctl clients -j`, which is what the "tab" command's
			// argument comes from, pretty-prints its JSON, so the payload
			// itself contains newlines. A single readLine() silently
			// truncated it at the first one, which produced a
			// syntactically broken argument that Quickshell's
			// JSON.parse() caught and discarded -- an empty window list,
			// so the switcher just never opened, with nothing about it
			// looking like an error anywhere in the chain.
			QObject::connect(client, &QLocalSocket::disconnected, [=]() {
				auto message = client->readAll().trimmed();

				if (!message.isEmpty()) {
					auto spaceIdx = message.indexOf(' ');
					auto function = spaceIdx < 0 ? QString::fromUtf8(message)
					                              : QString::fromUtf8(message.left(spaceIdx));

					QVector<QString> args;
					if (spaceIdx >= 0) {
						args.push_back(QString::fromUtf8(message.mid(spaceIdx + 1)));
					}

					if (ensureConnected()) {
						*qsStream << kStringCallCommandIndex;
						*qsStream << StringCallCommand {
						    .target = "alttab",
						    .function = function,
						    .arguments = args,
						};
						qsConn->flush();
					}
				}

				client->deleteLater();
			});
		}
	});

	// Polled rather than hooked into ensureConnected(): a round takes up to a
	// second per instance, and that path is a live Tab press. Every 5s is
	// plenty to catch a Quickshell restart. Nothing runs while the bar's
	// instance is known and still alive.
	auto* failRounds = new int(0);
	auto runSelfTest = [=]() {
		auto live = findLiveIpcSockets();
		if (!shellSock->isEmpty()) {
			if (live.contains(*shellSock)) return;
			qInfo() << "alttab-relay: Quickshell instance gone:" << *shellSock;
			shellSock->clear();
			qsConn->abort();
		}

		bool reachable = false;
		for (const auto& sockPath : live) {
			auto result = selfTest(sockPath);
			if (result == "unreachable") continue;
			reachable = true;
			if (result == "ok") {
				*shellSock = sockPath;
				*failRounds = 0;
				qsConn->abort();   // the next command connects to this one
				qInfo() << "alttab-relay: self-test passed against" << sockPath;
				return;
			}
		}
		if (!reachable || ++*failRounds != 3) return;

		qCritical().noquote() << "alttab-relay: SELF-TEST FAILED -- none of the"
			<< live.size() << "running Quickshell instance(s) answered the relay's ping."
			<< "If the bar is running, its private IPC wire format has probably changed"
			<< "in an update; alt-tab won't respond until alttab-relay.cpp is brought in"
			<< "line with it (or the relay is stopped, so alt-tab.sh falls back to"
			<< "`qs ipc call`).";
		QProcess::startDetached("notify-send", {
			"-a", "alttab-relay", "-u", "critical", "ALT+Tab relay out of date",
			"Quickshell isn't answering alttab-relay's IPC. See ~/.cache/alttab-relay.log",
		});
	};
	auto* selfTestTimer = new QTimer(&app);
	QObject::connect(selfTestTimer, &QTimer::timeout, runSelfTest);
	selfTestTimer->start(5000);
	QTimer::singleShot(0, &app, runSelfTest);

	qInfo() << "alttab-relay: listening on" << relaySockPath;

	return app.exec();
}
