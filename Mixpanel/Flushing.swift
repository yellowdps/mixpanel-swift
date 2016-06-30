//
//  Flushing.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 6/3/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

protocol FlushingDelegate {
    func flush()
    func updateNetworkActivityIndicator(_ on: Bool)
}

class Flushing {
    var serverURL = "https://api.mixpanel.com"
    var networkRequestsAllowedAfterTime: Double = 0
    var useIPAddressForGeoLocation = true
    var networkConsecutiveFailures = 0
    var timer: Timer?
    var delegate: FlushingDelegate?
    var _flushInterval: Double = 0
    var flushInterval: Double {
        set {
            objc_sync_enter(self)
            _flushInterval = newValue
            objc_sync_exit(self)

            delegate?.flush()
            startFlushTimer()
        }
        get {
            objc_sync_enter(self)
            defer { objc_sync_exit(self) }

            return _flushInterval
        }
    }

    enum FlushType: String {
        case Events = "/track/"
        case People = "/engage/"
    }

    func flushEventsQueue(_ eventsQueue: inout Queue) {
        flushQueue(.Events, queue: &eventsQueue)
    }

    func flushPeopleQueue(_ peopleQueue: inout Queue) {
        flushQueue(.People, queue: &peopleQueue)
    }

    func flushQueue(_ type: Flushing.FlushType, queue: inout Queue) {
        if Date().timeIntervalSince1970 < self.networkRequestsAllowedAfterTime {
            return
        }

        self.flushQueueAsync(&queue, type: type)
    }


    func startFlushTimer() {
        stopFlushTimer()
        DispatchQueue.main.async(execute: {
            if self.flushInterval > 0 {
                self.timer = Timer.scheduledTimer(timeInterval: self.flushInterval,
                                                  target: self,
                                                  selector: #selector(self.flushSelector),
                                                  userInfo: nil,
                                                  repeats: true)
            }
        })
    }

    @objc func flushSelector() {
        delegate?.flush()
    }

    func stopFlushTimer() {
        DispatchQueue.main.async(execute: {
            if let timer = self.timer {
                timer.invalidate()
            }
            self.timer = nil
        })
    }

    func flushQueueAsync(_ queue: inout Queue, type: FlushType) {
        while queue.count > 0 {
            var shouldContinue = false
            let batchSize = min(queue.count, 50)
            let range = 0..<batchSize
            let batch = Array(queue[range])
            let requestData = JSONHandler.encodeAPIData(batch)
            if let requestData = requestData {
                let semaphore = DispatchSemaphore(value: 0)
                flushRequest(requestData, type: type, completion: { success in
                    if success {
                        queue.removeSubrange(range)
                    }
                    shouldContinue = success
                    semaphore.signal()
                })
                _ = semaphore.wait(timeout: DispatchTime.distantFuture)
            }

            if !shouldContinue {
                break
            }
        }
    }

    private func flushRequest(_ requestData: String, type: FlushType, completion: (Bool) -> Void) {
        let responseParser: (Data) -> Int? = { data in
            let response = String(data: data, encoding: String.Encoding.utf8)
            if let response = response {
                //TODO: Should we allow 0 if it can't parse the response to an int?
                return Int(response) ?? 0
            }
            return nil
        }

        let requestBody = "ip=\(Int(self.useIPAddressForGeoLocation))&data=\(requestData)"
                .data(using: String.Encoding.utf8)
        delegate?.updateNetworkActivityIndicator(true)
        flushRequestHandler(self.serverURL,
                            resource: Resource(
                                path: type.rawValue,
                                method: Method.POST,
                                requestBody: requestBody,
                                headers: ["Accept-Encoding": "gzip"],
                                parse: responseParser),
                            completion: { success in
                                completion(success)
                                self.delegate?.updateNetworkActivityIndicator(false)
        })
    }

    private func flushRequestHandler(_ base: String,
                                     resource: Resource<Int>,
                                     completion: (Bool) -> Void) {
        NetworkingLayer.apiRequest(base: base,
                                   resource: resource,
                                   failure: { (reason, data, response) in
                self.networkConsecutiveFailures += 1
                self.updateRetryDelay(response)
                completion(false)
            }, completion: { (result, response) in
                self.networkConsecutiveFailures = 0
                self.updateRetryDelay(response)
                if result == 0 {
                    print("\(base) api rejected some items")
                }
                completion(true)
        })
    }

    private func updateRetryDelay(_ response: URLResponse?) {
        let retryTimeStr = (response as? HTTPURLResponse)?.allHeaderFields["Retry-After"] as? String
        var retryTime: Double = retryTimeStr != nil ? Double(retryTimeStr!)! : 0

        if self.networkConsecutiveFailures > 1 {
            retryTime = max(retryTime,
                            self.retryBackOffTimeWithConsecutiveFailures(
                                self.networkConsecutiveFailures))
        }
        let retryDate = Date(timeIntervalSinceNow: retryTime)
        self.networkRequestsAllowedAfterTime = retryDate.timeIntervalSince1970
    }

    private func retryBackOffTimeWithConsecutiveFailures(_ failureCount: Int) -> TimeInterval {
        let time = pow(2.0, Double(failureCount) - 1) * 60 + Double(arc4random_uniform(30))
        return min(max(60, time), 600)
    }

}
