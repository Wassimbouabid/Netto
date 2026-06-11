//
//  ParameterEncoding+multipart.swift
//  RevampCarSharing
//
//  Created by Bouabid Wassim on 25/12/2025.
//

import Foundation
internal import Alamofire

/// Converts a `[MultipartPart]` array to an Alamofire `MultipartFormData` object
/// for use with `Session.upload(multipartFormData:…)`.
internal extension Array where Element == MultipartPart {
    func toAlamofireMultipartFormData() -> MultipartFormData {
        let formData = MultipartFormData()
        for part in self {
            switch part.content {
            case .text(let value):
                if let data = value.data(using: .utf8) {
                    formData.append(data, withName: part.name)
                }
            case .data(let data, let mimeType, let filename):
                formData.append(data, withName: part.name, fileName: filename, mimeType: mimeType)
            case .fileURL(let url, let mimeType):
                if let mimeType {
                    formData.append(url, withName: part.name, fileName: url.lastPathComponent, mimeType: mimeType)
                } else {
                    formData.append(url, withName: part.name)
                }
            }
        }
        return formData
    }
}
