//
//  NetworkingLayer.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 6/2/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation


enum BasePath: String {
    case MixpanelAPI = "https://api.mixpanel.com"

    func getURL() -> URL {
        return URL(fileURLWithPath: self.rawValue)
    }
}

enum Method: String {
    case GET = "GET"
    case POST = "POST"
}

struct Resource<A> {
    let path: String
    let method: Method
    let requestBody: Data?
    let headers: [String:String]
    let parse: (Data) -> A?
}

enum Reason {
    case parseError
    case noData
    case notOKStatusCode(statusCode: Int)
    case other(NSError)
}

class NetworkingLayer {

    class func apiRequest<A>(base: String,
                          resource: Resource<A>,
                          failure: (Reason, Data?, URLResponse?) -> (),
                          completion: (A, URLResponse?) -> ()) {
        guard let request = createRequest(base, resource: resource) else {
            return
        }

        let session = URLSession.shared()
        session.dataTask(with: request) { (data, response, error) -> Void in
            guard let httpResponse = response as? HTTPURLResponse else {
                failure(Reason.other(error!), data, response)
                return
            }
            guard httpResponse.statusCode == 200 else {
                failure(Reason.notOKStatusCode(statusCode: httpResponse.statusCode), data, response)
                return
            }
            guard let responseData = data else {
                failure(Reason.noData, data, response)
                return
            }
            guard let result = resource.parse(responseData) else {
                failure(Reason.parseError, data, response)
                return
            }

            completion(result, response)
            }.resume()
    }

    private class func createRequest<A>(_ base: String, resource: Resource<A>) -> URLRequest? {
        guard let url = try? URL(string: base)?.appendingPathComponent(resource.path) else {
            return nil
        }

        guard let urlUnwrapped = url else {
            return nil
        }

        let request = NSMutableURLRequest(url: urlUnwrapped)
        request.httpMethod = resource.method.rawValue
        request.httpBody = resource.requestBody

        for (k, v) in resource.headers {
            request.setValue(v, forHTTPHeaderField: k)
        }
        return request as URLRequest
    }
}
