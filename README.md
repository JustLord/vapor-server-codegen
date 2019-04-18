# Swagger Codegen for the SwiftVapor3 framework

## Overview
Generates a package from a swagger spec file that can be imported by a [Vapor 3](https://vapor.codes) project. The package will contain a routes.swift, protocols to implement the APIs and data models.

This package was originally generated by the [Swagger Codegen](https://github.com/swagger-api/swagger-codegen) tool.

This project was designed so that you start your API from a swagger spec. Then using this tool generate the Vapor Server interface as a package. Your Vapor project will depend on the new interface package and us the auto-generated `routes.swift`, API Interfaces and data models. See instructions below on how to consume the package's interfaces.

I hope that you find this project to be useful. I would like to see server side swift adopted more commonly as I love the swift language for its performance and other conveniences. Vapor is a low memory, low cpu web server and hope to see it become well established in the future. Now if you get an API swagger definition file, you can get starte fairly quickly using this project. And if you don't have a swagger spec file to start from, I would recommend starting to write an API by defining the swagger spec file first. This project should reduce the overhead of going from API design to compiling working code as you make changes to your APIs.

Let me know if you run into issues with this project or its documentation. Help is welcome!

## How do I build this project?

As of now, you must generate your own jar file. Check out or download the complete source.


```
git clone https://github.com/thecheatah/SwiftVapor-swagger-codegen
cd SwiftVapor-swagger-codegen
mvn package
```

The `mvn package` command will run test that include a swift project. This project was created on MacOS with Swift 5 installed. To ignore tests run `mvn -Dmaven.test.skip=true package`. The project also contains `SwiftVapor3Codegen/src/test/resources/swift/VaporTestServer/run_linux_test` to run the tests in a docker container.

## How do I run this project?

Once the package has been created, you will find `SwiftVapor3-swagger-codegen-1.0.0.jar` in the `target` directory.

You can now generate the Vapor Server Interface Package from a swagger file.

```
java -cp SwiftVapor3-swagger-codegen-1.0.0.jar:swagger-codegen-cli-3.0.7.jar io.swagger.codegen.v3.cli.SwaggerCodegen generate -l SwiftVapor3 -i ./codegen_test.yml -o ./output/MyApiVaporInterface --additional-properties projectName=MyApiVaporInterface
```

The `swagger-codegen-cli-3.0.7.jar` can be built from the [swagger-codegen](https://github.com/swagger-api/swagger-codegen) package. Personally, I use the one from maven `.m2/repository/io/swagger/codegen/v3/swagger-codegen-cli/3.0.7/swagger-codegen-cli-3.0.7.jar` This project depends on it and will be pulled in to your maven cache.

## How do I use the auto-generated package?

The auto-generated package will contain 3 key directories:

```
|- Sources
|-- {Package Name}
|--- routes.swift
|--- APIs
|---- {Swagger Tag 1}ApiDelegate.swift
|---- {Swagger Tag 2}ApiDelegate.swift
|--- Models
|---- {Swagger Model 1}.swift
|---- {Swagger Model 2}.swift
```

`routes.swift` will contain a public function where the `Router` and controllers implementing the protocols defined in the APIs directory need to be passed in. The protocols defined in the APIs directory provide the key interface that your code needs to interact with. The interface provided is designed to exchange simple data types or models created from the swagger. The `Models` directory contains all of the models generated from the swagger spec.
### 1. Define dependency
In order to use the auto-generated package, your Vapor project needs to define a dependency on the package. The swift project included to run test cases has an example `Package.swift` that defines such a dependency.

```swift
// swift-tools-version:4.2
import PackageDescription

let package = Package(
    name: "VaporTestServer",
    products: [
        .library(name: "VaporTestServer", targets: ["App"]),
        ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "3.0.0"),
        
        // 🔵 Swift ORM (queries, models, relations, etc) built on SQLite 3.
        .package(url: "https://github.com/vapor/fluent-sqlite.git", from: "3.0.0"),
        .package(path: "../VaporTestInterface/")
    ],
    targets: [
        .target(name: "App", dependencies: ["FluentSQLite", "Vapor", "VaporTestInterface"]),
        .target(name: "Run", dependencies: ["App"]),
        .testTarget(name: "AppTests", dependencies: ["App"])
    ]
)
```
In the example above the generated package is `VaporTestInterface` and is located next to the `VaporTestServer` vapor project.

### 2. Implement API by creating Controllers

Next, you will need to create controller classes for each of the APIs defined within the swagger. The swagger-codegen defaults to generating an API for each tag used in swagger spec. Each controller class will need to implement the specific API's interface as defined within the generated package.

```swift
import Vapor
import VaporTestInterface

class DataModelController: DataModelApiDelegate {
  func referencedObject(request: Request, body: SimpleObject) throws -> Future<referencedObjectResponse> {
    return request.future(.http200(body))
  }
}
```

In the example above the `DataModelController` class is in a file within your project. `DataModelApiDelegate` is from the auto-generated package `VaporTestInterface`.

Required flags are respected and determines if a field is optional or not.

#### 2.1 Response Codes in Controllers

The generated interface is designed to handle HTTP response codes by building an enum for each possible response code. The enum is parameterized to take in the payload to be returned for each response code.

```swift
public enum multipleResponseCodesResponse: ResponseEncodable {
  case http200
  case http201(SimpleObject)
  case http401
  case http500

  public func encode(for request: Request) throws -> EventLoopFuture<Response> {
    let response = request.response()
    switch self {
    case .http200:
      response.http.status = HTTPStatus(statusCode: 200)
    case .http201(let content):
      response.http.status = HTTPStatus(statusCode: 201)
      try response.content.encode(content)
    case .http401:
      response.http.status = HTTPStatus(statusCode: 401)
    case .http500:
      response.http.status = HTTPStatus(statusCode: 500)
    }
    return Future.map(on: request) { response }
  }
}
```

Here are examples of returning various response codes:

```swift
func multipleResponseCodes(with req: Request, body: MultipleResponseCodeRequest) throws -> EventLoopFuture<multipleResponseCodesResponse> {
  switch body.responseCode {
  case MultipleResponseCodeRequest.ResponseCode._200:
    return req.future(.http200)
  case MultipleResponseCodeRequest.ResponseCode._201:
    return req.future(.http201(SimpleObject(simpleString: "Simple String", simpleNumber: 44.22, simpleInteger: 44, simpleDate: Date(), simpleEnumString: ._1, simpleBoolean: false, simpleArray: ["Hi!"])))
  case MultipleResponseCodeRequest.ResponseCode._401:
    return req.future(.http401)
  case MultipleResponseCodeRequest.ResponseCode._500:
    return req.future(.http500)
  }
}
```

#### 2.2 Body in Controllers

A POST/PATCH/etc. request and a response body will map to an API interface as such:

```swift
func referencedObject(with req: Request, body: SimpleObject) throws -> Future<referencedObjectResponse> {
  return req.future(.http200(body))
}
```

This library is designed to only handle json responses. The swagger spec supports multiple response types and the "enum" approach could be extended to handle multiple response types. It's not something that is currently supported.

#### 2.3 GET Parameters in Controllers

GET parameters map to function parameters within a controller. In the example below param1 and param2 are get parameters like ?param1=string&param2=44

```swift
func queryParameters(with req: Request, param1: String, param2: Int?) throws -> EventLoopFuture<queryParametersResponse> {
  return req.future(.http200(QueryParametersResponse(param1: param1, param2: param2)))
}
```

#### 2.4 Path Parameters in Controllers

Parameters within a path are always handled as strings. The /path/{param1}/and/{param2} path parameters will generate the following:

```swift
func multipleParameter(with req: Request, param1: String, param2: String) throws -> EventLoopFuture<multipleParameterResponse> {
  return req.future(.http200(MultipleParameterResponse(param1: param1, param2: param2)))
}
```

#### 2.5 Headers in Controllers

Headers from requests and responses will generate an interface like this:

```swift
class HeadersController: HeadersApiDelegate {
  typealias AuthType = SampleAuthType

  func responseHeaders(with req: Request) throws -> EventLoopFuture<responseHeadersResponse> {
    return req.future(.http303(location: "https://chckt.com/login"))
  }
  
  func requestHeaders(with req: Request, xExampleRequiredHeader: String, xExampleArrayHeader: [String]) throws -> EventLoopFuture<requestHeadersResponse> {
    return req.future(.http200(RequestHeadersResponse(requiredHeader: xExampleRequiredHeader, arrayHeader: xExampleArrayHeader)))
  }
}
```

#### 2.6 Form Parameters in Controllers

The swagger-codegen library flattens the first level of the data model representing the form parameters.

```YAML
    SimpleObject:
      type: object
      required: [simpleString, simpleNumber, simpleInteger, simpleDate, simpleEnumString, simpleBoolean, simpleArray]
      properties:
        simpleString:
          $ref: '#/components/schemas/SimpleString'
        simpleNumber:
          $ref: '#/components/schemas/SimpleNumber'
        simpleInteger:
          $ref: '#/components/schemas/SimpleInteger'
        simpleDate:
          $ref: '#/components/schemas/SimpleDate'
        simpleEnumString:
          $ref: '#/components/schemas/SimpleEnumString'
        simpleBoolean:
          $ref: '#/components/schemas/SimpleBoolean'
        simpleArray:
          type: array
          items:
            $ref: '#/components/schemas/SimpleString'
```

Would map to:

```swift
func formRequest(with req: Request, simpleString: SimpleString, simpleNumber: SimpleNumber, simpleInteger: SimpleInteger, simpleDate: SimpleDate, simpleEnumString: SimpleEnumString, simpleBoolean: SimpleBoolean, simpleArray: [SimpleString]) throws -> EventLoopFuture<formRequestResponse> {
  return req.future(.http200(SimpleObject(simpleString: simpleString, simpleNumber: simpleNumber, simpleInteger: simpleInteger, simpleDate: simpleDate, simpleEnumString: simpleEnumString, simpleBoolean: simpleBoolean, simpleArray: simpleArray)))
}
```

#### 2.7 Authentication in Controllers

Due to the limitation of how the codegen represents swagger and how I wanted to generate the interface, this generator can only handle one authentication mechanism per endpoint.

If multiple authentication mechanisms are used, a single endpoint can only handle one authentication mechanism, but different endpoints can handle different authentication mechanisms. The "AuthType" object type set from the multiple authentication mechanisms must be the same. This library uses generics to enforce that.

Here is an example interface from the test suite. The "as" parameter will contain the object authenticated by the authenticator.

```swift
class AuthenticationController: AuthenticationApiDelegate {
  typealias AuthType = SampleAuthType

  func securityProtectedEndpoint(with req: Request, as from: SampleAuthType) throws -> EventLoopFuture<securityProtectedEndpointResponse> {
    return req.future(.http200(SecurityProtectedEndpointResponse(secret: from.secret)))
  }
}
```

The authenticator is a Vapor Middleware, but needs to extend AuthenticationMiddleware from the generated library. The interface for AuthenticationMiddleware is as follows:

```swift
public protocol AuthenticationMiddleware: Middleware {
  associatedtype AuthType: Authenticatable
  func authType() -> AuthType.Type
}
```

Here is an example authentication middleware:

```swift
import Vapor
import Authentication
import VaporTestInterface

struct SampleAuthType: Authenticatable {
  let secret: String
}

class SecurityMiddleware: AuthenticationMiddleware {
  typealias AuthType = SampleAuthType
  
  func authType() -> SampleAuthType.Type {
    return SampleAuthType.self
  }

  func respond(to request: Request, chainingTo next: Responder) throws -> EventLoopFuture<Response> {
    guard let bearer = request.http.headers.bearerAuthorization else {
      throw Abort(.unauthorized)
    }
    if bearer.token != "Secret" {
      throw Abort(.unauthorized)
    }
    try request.authenticate(SampleAuthType(secret: bearer.token))
    return try next.respond(to: request)
  }
}
```

In the example above, note that the middleware sets `try request.authenticate(SampleAuthType(secret: bearer.token))` where the authenticated object is the same type `SampleAuthType` as `typealias AuthType = SampleAuthType`. 

The authentication middleware needs to be passed in the generated interface's `routes` method as a parameter.

This is the generated routes interface from the test suite. You don't need to understand what it does, but know that it uses generics to map the `AuthType` returned from the authenticator to the `AuthType`.

```swift
public func routes<authForSecurity1: AuthenticationMiddleware, authentication: AuthenticationApiDelegate, dataModel: DataModelApiDelegate, formData: FormDataApiDelegate, headers: HeadersApiDelegate, multipleResponseCodes: MultipleResponseCodesApiDelegate, pathParsing: PathParsingApiDelegate, queryParameters: QueryParametersApiDelegate>
  (_ router: Router, authentication: authentication, dataModel: dataModel, formData: formData, headers: headers, multipleResponseCodes: multipleResponseCodes, pathParsing: pathParsing, queryParameters: queryParameters, authForSecurity1: authForSecurity1)
  throws
  where authForSecurity1.AuthType == authentication.AuthType, authForSecurity1.AuthType == dataModel.AuthType, authForSecurity1.AuthType == formData.AuthType, authForSecurity1.AuthType == headers.AuthType, authForSecurity1.AuthType == multipleResponseCodes.AuthType, authForSecurity1.AuthType == pathParsing.AuthType, authForSecurity1.AuthType == queryParameters.AuthType
```

The first parameter in the `routes` will be the `Router` from the Vapor library, the next set of parameters will be the Controllers implementing the delegates followed by the authenticator.

##### 2.7.1 Controllers without Authentication

When generating the API delegate, the swagger library does not pass in the authentication schemes used by the API's operations and the mustache template engine does not allow one to aggregate the authentication schemes used within an API's operations. Thus, this library, regardless if authentication is used within the swagger or not, will generate a `associatedtype AuthType` in the generated API protocol. A default `DummyAuthType` is provided that needs to be set on a controller whose operations do not use an authentication.

Here is what the DummyAuthType looks like:
```swift
//Used when auth is not used
public class DummyAuthType: Authenticatable {}
```

Here is an example of a Controller setting the dummy auth type:
```swift
class DataModelController: DataModelApiDelegate {
  typealias AuthType = DummyAuthType.Type

  func referencedObject(with req: Request, body: SimpleObject) throws -> Future<referencedObjectResponse> {
    return req.future(.http200(body))
  }
}
```

If any of the controllers uses an authentication mechanism, all other controllers must set the `AuthType` to the same. The authentication mechanism must also set the same auth type object.

### 3. Configure the router

The generated package will contain a `routes.swift`. This file will contain a public function `public func routes(_ router: Router, ...`. You can call this function from the `routes.swift` from your vapor project and pass in the `Router` as well as the controllers implementing the API interfaces.

Once this step is done, you can now run the vapor server (`vapor run`) from your project and try out the APIs.

## Your Code SuX, How do I make changes to it?

When I work on this project, I work on a Mac and use xcode. I have included linux build script using docker that runs the swift test cases in a docker image. If you want to do development on Linux or Windows, there is nothing theoretically stopping you.

To get into the grove of making changes, running tests, adding new functionality and adding test cases, you should configure the project locally as follows:

### 1. Get the project to build

At a minimum, you need to install Maven, and I would recommend a java IDE like Eclipse. Once you have maven installed you can run `mvn package` to build, run tests and produce a jar. If the tests fail for some reason and you still want a jar, you can run `mvn -Dmaven.test.skip=true package`

### 2. Setup for swift development

Once you can see that the java project works, you should configure the swift project as well for development

In the root of the project run the following commands:

```shell
cd test/resources/AllTest
ln -s ../../../../target/test-classes/AllTest/VaporTestInterface ./
cd ../../..
cd test/resources/WithoutAuthTest
ln -s ../../../../target/test-classes/WithoutAuthTest/VaporTestInterface ./
cd ../../..
```
The java tests build `VaporTestInterface` under `target/test-classes/swift/`. If you link it like this, you can run the xcode tests right from the xcode test project.

### 3. Setup for running tests in swift

Again in the root of the project folder:
```shell
cd src/test/resources/swift/VaporTestServer
vapor xcode
```

The `vapor xcode` command will ask if you want to open the xcode project. Hit yes and it will launch xcode. You can hit run and see the test project build. I mainly use it to run the tests. So go to the tests section in xcode and run all of them from there.

If you don't want to use xcode you can simply run `swift test` in the `src/test/resources/swift/VaporTestServer` directory.

### 4. Edit, build, test cycle

Now you are ready for the edit, build, test cycle.

1. You can edit the java code as well as the mustache templates in the java project
2. Run `mvn -Dmaven.test.skip=true package` to build the java package
3. Run codegen `src/test/resources/run_codegen.sh`
3. Run the tests in swift using xcode or the commandline

I mostly edited the mustache templates in this project. `run_codegen.sh` pipes the output by default to a file in the same directory called `codegen.out`. It's configured to dump the json payloads that are fed into the mustache template engine. Each generated swift file has a "Template Input" line like this: `Template Input: /APIs.FormData`. In the example template input line you can search for `/APIs.FormData` in the `codegen.out` file and find the json payload. I usually copy that subset of the json payload into Chrome/Safari/Firefox's developer console. For example I will do `var json = command+v` and then press up and type in `json` and hit enter. The browser's developer console will let you browse the json tree easily.

### Original Swagger Codegen Instructions

The instructions below were generated automatically by the swagger-codegen build script. I have kept them here to assist users new to the swagger-codegen tool. (It's Awesome!)

At this point, you've likely generated a client setup.  It will include something along these lines:

```
.
|- README.md    // this file
|- pom.xml      // build script
|-- src
|--- main
|---- java
|----- com.chckt.swagger.swift.vapor3.Swiftvapor3Generator.java // generator file
|---- resources
|----- SwiftVapor3 // template files
|----- META-INF
|------ services
|------- io.swagger.codegen.CodegenConfig
```

You _will_ need to make changes in at least the following:

`Swiftvapor3Generator.java`

Templates in this folder:

`src/main/resources/SwiftVapor3`

Once modified, you can run this:

```
mvn package
```

In your generator project.  A single jar file will be produced in `target`.  You can now use that with codegen:

```
java -cp /path/to/swagger-codegen-cli.jar:/path/to/your.jar io.swagger.codegen.Codegen -l SwiftVapor3 -i /path/to/swagger.yaml -o ./test
```

Now your templates are available to the client generator and you can write output values

## But how do I modify this?
The `Swiftvapor3Generator.java` has comments in it--lots of comments.  There is no good substitute
for reading the code more, though.  See how the `Swiftvapor3Generator` implements `CodegenConfig`.
That class has the signature of all values that can be overridden.

For the templates themselves, you have a number of values available to you for generation.
You can execute the `java` command from above while passing different debug flags to show
the object you have available during client generation:

```
# The following additional debug options are available for all codegen targets:
# -DdebugSwagger prints the OpenAPI Specification as interpreted by the codegen
# -DdebugModels prints models passed to the template engine
# -DdebugOperations prints operations passed to the template engine
# -DdebugSupportingFiles prints additional data passed to the template engine

java -DdebugOperations -cp /path/to/swagger-codegen-cli.jar:/path/to/your.jar io.swagger.codegen.Codegen -l SwiftVapor3 -i /path/to/swagger.yaml -o ./test
```

Will, for example, output the debug info for operations.  You can use this info
in the `api.mustache` file.