
## Swift implementation of NAT type detection
Inspired by https://github.com/HMBSbige/NatTypeTester
<br>
Issue and pull request are welcomed

### Swift Package Manager

The [Swift Package Manager](https://swift.org/package-manager/) is a tool for automating the distribution of Swift code and is integrated into the `swift` compiler. 

Once you have your Swift package set up, adding SwiftNATTypeDetector as a dependency is as easy as adding it to the `dependencies` value of your `Package.swift`.

```swift
dependencies: [
    .package(url: "https://github.com/swarm-cloud/SwiftNATTypeDetector.git", .upToNextMajor(from: "0.0.1"))
]
```

## NAT类型探测的Swift实现

参照了c#版的实现：https://github.com/HMBSbige/NatTypeTester
<br>
欢迎测试效果并反馈issue
