import Vapor
// QueryParametersApiDelegate.swift
//
// Generated by SwiftVapor3 swagger-codegen
// https://github.com/swagger-api/swagger-codegen
// Template Input: /APIs.QueryParameters


public enum queryParametersResponse: ResponseEncodable {
  case http200(QueryParametersResponse)

  public func encode(for request: Request) throws -> EventLoopFuture<Response> {
    let response = request.response()
    switch self {
    case .http200(let content):
      response.http.status = HTTPStatus(statusCode: 200)
      try response.content.encode(content)
    }
    return Future.map(on: request) { response }
  }
}

public protocol QueryParametersApiDelegate {
  associatedtype AuthType
  /**
  GET /query/parameter
  Query parameter test */
  func queryParameters(with req: Request, param1: String, param2: Int?) throws -> Future<queryParametersResponse>
}