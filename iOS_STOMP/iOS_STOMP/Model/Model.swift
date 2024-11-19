//
//  Model.swift
//  iOS_STOMP
//
//  Created by 아티젠스페이스 on 11/19/24.
//

// StompClient.swift

import Foundation
import Starscream

protocol StompClientDelegate: AnyObject {
    func didReceiveGiftEvents(_ events: GiftEventResponse)
    func didConnect()
    func didDisconnect(error: Error?)
}

final class StompClient {
    private var webSocket: WebSocket?
    private weak var delegate: StompClientDelegate?
    private var isConnected = false
    private var messageQueue: [String] = []
    
    init(url: URL, delegate: StompClientDelegate) {
        self.delegate = delegate
        setupWebSocket(with: url)
    }
    
    private func setupWebSocket(with url: URL) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        
        webSocket = WebSocket(request: request)
        webSocket?.delegate = self
    }
    
    func connect() {
        webSocket?.connect()
    }
    
    func disconnect() {
        webSocket?.disconnect()
        isConnected = false
    }
    
    private func sendStompConnect() {
        let connectFrame = """
        CONNECT
        accept-version:1.1,1.0
        heart-beat:10000,10000
        
        \u{0}
        """
        webSocket?.write(string: connectFrame)
    }
    
    func subscribe(to destination: String) {
        let subscribeFrame = """
        SUBSCRIBE
        id:sub-0
        destination:\(destination)
        
        \u{0}
        """
        if isConnected {
            webSocket?.write(string: subscribeFrame)
        } else {
            messageQueue.append(subscribeFrame)
        }
    }
    
    func send(
        to destination: String,
        body: String
    ) {
        let contentLength = body.lengthOfBytes(using: .utf8)
        let sendFrame = """
        SEND
        destination:\(destination)
        content-length:\(contentLength)
        
        \(body)\u{0}
        """
        if isConnected {
            webSocket?.write(string: sendFrame)
        } else {
            messageQueue.append(sendFrame)
        }
    }
    
    private func processMessageQueue() {
        messageQueue.forEach { frame in
            webSocket?.write(string: frame)
        }
        messageQueue.removeAll()
    }
    
    private func handleStompMessage(_ text: String) {
        print("📩 Received STOMP message:")
        print(text)  // Raw message logging
        
        let components = text.components(separatedBy: "\n\n")
        guard components.count >= 2 else {
            print("❌ Invalid message format")
            return
        }
        
        let headers = components[0]
        let body = components[1].replacingOccurrences(of: "\u{0}", with: "")
        
        if headers.starts(with: "CONNECTED") {
            print("✅ Connected to STOMP server")
            isConnected = true
            delegate?.didConnect()
            processMessageQueue()
        } else if headers.contains("MESSAGE") {
            print("📦 Message body:")
            print(body)
            handleMessageBody(body)
        }
    }

    private func handleMessageBody(_ body: String) {
        guard let data = body.data(using: .utf8) else {
            print("❌ Failed to convert body to data")
            return
        }
        
        do {
            let response = try JSONDecoder().decode(GiftEventResponse.self, from: data)
            print("✅ Successfully decoded GiftEventResponse:")
            print(response)
            delegate?.didReceiveGiftEvents(response)
        } catch {
            print("❌ Error decoding message: \(error)")
        }
    }
}

// MARK: - WebSocketDelegate
extension StompClient: WebSocketDelegate {
    
    func didReceive(event: WebSocketEvent, client: any Starscream.WebSocketClient) {
        switch event {
        case .connected(_):
            sendStompConnect()
            
        case .disconnected(let reason, let code):
            isConnected = false
            let error = NSError(
                domain: "WebSocket",
                code: Int(code),
                userInfo: [NSLocalizedDescriptionKey: reason]
            )
            delegate?.didDisconnect(error: error)
            
        case .text(let text):
            handleStompMessage(text)
            
        case .error(let error):
            isConnected = false
            delegate?.didDisconnect(error: error)
            
        default:
            break
        }
    }
}

// WebSocketService.swift

final class WebSocketService {
    static let shared = WebSocketService()
    private var stompClient: StompClient?
    private weak var delegate: StompClientDelegate?
    
    private let baseURL = "ws://192.168.0.48:9010/wyftws"
    
    private init() {}
    
    func setDelegate(_ delegate: StompClientDelegate) {
        self.delegate = delegate
        
        guard
            let url = URL(string: baseURL)
        else { return }
        
        stompClient = StompClient(url: url, delegate: delegate)
    }
    
    func connect() {
        stompClient?.connect()
    }
    
    func disconnect() {
        stompClient?.disconnect()
    }
    
    func subscribeToGiftEvents(memberUuid: String) {
        let topic = "/topic/gift/events/\(memberUuid)"
        stompClient?.subscribe(to: topic)
    }
    
    func sendGiftEventRequest(
        memberUuid: String,
        longitude: String,
        latitude: String,
        category: String = "ALL",
        startDate: String,
        endDate: String
    ) {
        let destination = "/pub/gift/events/\(memberUuid)"
        
        let request = GiftEventRequest(
            memberUuid: memberUuid,
            longitude: longitude,
            latitude: latitude,
            category: category,
            startDate: startDate,
            endDate: endDate
        )
        
        guard
            let jsonData = try? JSONEncoder().encode(request),
            let jsonString = String(data: jsonData, encoding: .utf8)
        else { return }
        
        stompClient?.send(to: destination, body: jsonString)
    }
}

// NetworkService Extension
//extension NetworkService {
//    func connectToWebSocket() {
//        WebSocketService.shared.connect()
//    }
//    
//    func disconnectFromWebSocket() {
//        WebSocketService.shared.disconnect()
//    }
//    
//    func subscribeToGiftEvents(memberUuid: String) {
//        WebSocketService.shared.subscribeToGiftEvents(memberUuid: memberUuid)
//    }
//    
//    func sendGiftEventRequest(
//        memberUuid: String,
//        longitude: String,
//        latitude: String,
//        category: String = "ALL",
//        startDate: String,
//        endDate: String
//    ) {
//        WebSocketService.shared.sendGiftEventRequest(
//            memberUuid: memberUuid,
//            longitude: longitude,
//            latitude: latitude,
//            category: category,
//            startDate: startDate,
//            endDate: endDate
//        )
//    }
//}

// Models.swift
struct GiftEventRequest: Codable {
    let memberUuid: String
    let longitude: String
    let latitude: String
    let category: String
    let startDate: String
    let endDate: String
}

// MARK: - GiftEventResponse
//struct GiftEventResponse: Codable {
//    let giftCategory: GiftCategory
//}
//
//// MARK: - GiftCategory
//struct GiftCategory: Codable {
//    let receive: Receive
//    let send: Send
//
//    enum CodingKeys: String, CodingKey {
//        case receive = "RECEIVE"
//        case send = "SEND"
//    }
//}
//
//// MARK: - Receive
//struct Receive: Codable {
//    let video: Video
//    let receiveDefault: Default
//    let basket: [Basket
//    enum CodingKeys: String, CodingKey {
//        case video = "VIDEO"
//        case receiveDefault = "Default"
//    }
//}
//
//// MARK: - Default
//struct Default: Codable {
//    let both: [Both]
//}
//
//// MARK: - Both
//struct Both: Codable {
//    let giftName: String
//    let latitude: Double
//    let insertDate: String
//    let activate: Bool
//    let giftKey: Int
//    let longitude: Double
//    let status: Status
//}
//
//enum Status: String, Codable {
//    case play = "PLAY"
//    case ready = "READY"
//    case statusOPEN = "OPEN"
//}
//
//// MARK: - Video
//struct Video: Codable {
//    let perOnly: [PerOnly]
//    let both: [Both]
//}
//
//// MARK: - PerOnly
//struct PerOnly: Codable {
//    let giftName: String
//    let insertDate: String
//    let activate: Bool
//    let giftKey: Int
//    let status: Status
//}
//
//// MARK: - Send
//struct Send: Codable {
//    let basket: Default
//    let sendDefault: Video
//
//    enum CodingKeys: String, CodingKey {
//        case basket = "Basket"
//        case sendDefault = "Default"
//    }
//}

// MARK: - GiftEventResponse
struct GiftEventResponse: Codable {
    let giftCategory: GiftCategory
}

// MARK: - GiftCategory
struct GiftCategory: Codable {
    let receive: GiftType?
    let send: GiftType?

    enum CodingKeys: String, CodingKey {
        case receive = "RECEIVE"
        case send = "SEND"
    }
}

struct GiftType: Codable {
    let basket: GiftData?
    let giftDefault: GiftData?
    let treasure: GiftData?
    let video: GiftData?
    
    enum CodingKeys: String, CodingKey {
        case basket = "Basket"
        case giftDefault = "Default"
        case treasure = "Treasure"
        case video = "Video"
    }
}


struct GiftData: Codable {
    let no: [No]?
    let perOnly: [PerOnly]?
    let locOnly: [LocOnly]?
    let both: [Both]?
}

// MARK: - PerOnly
struct PerOnly: Codable {
    let giftName: String
    let activate: Bool
    let insertDate: String
    let giftKey: Int
    let status: String
    let startDate, endDate: String
}

// MARK: - LocOnly
struct LocOnly: Codable {
    let giftName: String
    let activate: Bool
    let insertDate: String
    let giftKey: Int
    let status: String
    let latitude, longitude: Double
}

// MARK: - Both
struct Both: Codable {
    let giftName: String
    let latitude, longitude: Double
    let activate: Bool
    let insertDate: String
    let giftKey: Int
    let startDate, endDate: String
    let status: Status
}

// MARK: - Status
enum Status: String, Codable {
    case play = "PLAY"
    case ready = "READY"
    case statusOPEN = "OPEN"
}

// MARK: - No
struct No: Codable {
    let giftName: String
    let activate: Bool
    let insertDate: String
    let giftKey: Int
    let status: Status
}
