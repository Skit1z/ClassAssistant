import Foundation

@MainActor
final class AlertWebSocketClient {
    private let session: URLSession
    private let url = URL(string: "ws://127.0.0.1:8765/api/ws/alerts")!

    private var task: URLSessionWebSocketTask?
    private var heartbeatTimer: Timer?
    private var shouldReconnect = false
    private var reconnectWorkItem: DispatchWorkItem?

    var onAlert: ((AlertMessage) -> Void)?
    var onConnectionChange: ((Bool) -> Void)?

    init(session: URLSession = .shared) {
        self.session = session
    }

    func connect() {
        guard task == nil else {
            return
        }

        shouldReconnect = true
        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()
        onConnectionChange?(true)
        scheduleHeartbeat()
        receiveNextMessage()
    }

    func disconnect() {
        shouldReconnect = false
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        onConnectionChange?(false)
    }

    private func receiveNextMessage() {
        task?.receive { [weak self] result in
            Task { @MainActor in
                guard let self else {
                    return
                }

                switch result {
                case .success(let message):
                    self.handle(message: message)
                    self.receiveNextMessage()
                case .failure:
                    self.handleDisconnect()
                }
            }
        }
    }

    private func handle(message: URLSessionWebSocketTask.Message) {
        let payload: Data?

        switch message {
        case .data(let data):
            payload = data
        case .string(let string):
            payload = string.data(using: .utf8)
        @unknown default:
            payload = nil
        }

        guard let payload,
              let alert = try? JSONDecoder().decode(AlertMessage.self, from: payload),
              alert.type == "keyword_alert" else {
            return
        }

        onAlert?(alert)
    }

    private func handleDisconnect() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        task = nil

        onConnectionChange?(false)

        guard shouldReconnect else {
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            self?.connect()
        }
        reconnectWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: workItem)
    }

    private func scheduleHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.task?.sendPing { _ in }
            }
        }
    }
}
