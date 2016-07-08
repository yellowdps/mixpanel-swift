//
//  Network.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 6/2/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation


struct BasePath {
    static var MixpanelAPI = "https://api.mixpanel.com"
    
    static func getURL(str: String) -> URL? {
        if let url = URL(string:str) {
            return url
        }
        return nil
    }
}

enum Method: String {
    case GET
    case POST
}

struct Resource<A> {
    let path: String
    let method: Method
    let requestBody: Data?
    let headers: [String:String]
    let parse: (Data) -> A?
}

enum Reason {
    case ParseError
    case NoData
    case NotOKStatusCode(statusCode: Int)
    case Other(NSError)
}

class Network {
    
    class func apiRequest<A>(base: String,
                          resource: Resource<A>,
                          failure: (Reason, Data?, URLResponse?) -> (),
                          success: (A, URLResponse?) -> ()) {
        guard let request = createRequest(base, resource: resource) else {
            return
        }
        
        let session = URLSession.shared()
        session.dataTask(with: request) { (data, response, error) -> Void in
            guard let httpResponse = response as? HTTPURLResponse else {
                failure(Reason.Other(error!), data, response)
                return
            }
            guard httpResponse.statusCode == 200 else {
                failure(Reason.NotOKStatusCode(statusCode: httpResponse.statusCode), data, response)
                return
            }
            guard let responseData = data else {
                failure(Reason.NoData, data, response)
                return
            }
            guard let result = resource.parse(responseData) else {
                failure(Reason.ParseError, data, response)
                return
            }
            
            success(result, response)
        }.resume()
    }
    
    private class func createRequest<A>(_ base: String, resource: Resource<A>) -> URLRequest? {
        guard let url = try? URL(string: base)?.appendingPathComponent(resource.path) else {
            return nil
        }
        
        guard let urlUnwrapped = url else {
            return nil
        }
        
        var request = URLRequest(url: urlUnwrapped)
        request.httpMethod = resource.method.rawValue
        request.httpBody = resource.requestBody
        
        for (k, v) in resource.headers {
            request.setValue(v, forHTTPHeaderField: k)
        }
        return request as URLRequest
    }
    
    class func buildResource<A>(path: String, method: Method, requestBody: Data?, headers: [String: String], parse: (Data) -> A?) -> Resource<A> {
        return Resource(path: path, method: method, requestBody: requestBody, headers: headers, parse: parse)
    }
}
