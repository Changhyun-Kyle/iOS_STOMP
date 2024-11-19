//
//  ViewController.swift
//  iOS_STOMP
//
//  Created by 아티젠스페이스 on 11/19/24.
//

import UIKit

class ViewController: UIViewController, StompClientDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 델리게이트 설정
        WebSocketService.shared.setDelegate(self)
        
        // 웹소켓 연결
        WebSocketService.shared.connect()
    }
    
    func didConnect() {
        print("WebSocket Connected")
        
        // 연결 성공 후 구독 및 이벤트 요청
        let memberUuid = "hvbkkuDrJDZFP23ZSaguk8rbQBF3"
//        let memberUuid = "testㅁ1"
        WebSocketService.shared.subscribeToGiftEvents(memberUuid: memberUuid)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            WebSocketService.shared.sendGiftEventRequest(
                memberUuid: memberUuid,
                longitude: "0.0",
                latitude: "0.0",
                startDate: "",
                endDate: ""
            )
        }
    }
    
    func didReceiveGiftEvents(_ events: GiftEventResponse) {
        // 받은 이벤트 처리
        print(#file + "/" + #function + ": \(events)")
    }
    
    func didDisconnect(error: Error?) {
        if let error = error {
            print("WebSocket Disconnected with error: \(error)")
        } else {
            print("WebSocket Disconnected")
        }
    }
}
