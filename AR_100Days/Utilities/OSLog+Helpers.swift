import os.log

public let appSubsystem = "tokyo.shmdevelopment.AR_100Days"
public let appLog = OSLog(subsystem: appSubsystem, category: "AR_100Days")

extension OSLog {

    @usableFromInline
    internal func log(_ type: OSLogType, _ message: StaticString, _ args: [CVarArg]) {
        // The Swift overlay of os_log prevents from accepting an unbounded number of args
        assert(args.count <= 8)
        switch args.count {
        case 8: os_log(type, log: self, message, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7])
        case 7: os_log(type, log: self, message, args[0], args[1], args[2], args[3], args[4], args[5], args[6])
        case 6: os_log(type, log: self, message, args[0], args[1], args[2], args[3], args[4], args[5])
        case 5: os_log(type, log: self, message, args[0], args[1], args[2], args[3], args[4])
        case 4: os_log(type, log: self, message, args[0], args[1], args[2], args[3])
        case 3: os_log(type, log: self, message, args[0], args[1], args[2])
        case 2: os_log(type, log: self, message, args[0], args[1])
        case 1: os_log(type, log: self, message, args[0])
        default: os_log(type, log: self, message)
        }
    }

    @inlinable
    public func log(_ formatString: StaticString, _ args: CVarArg...) {
        log(.default, formatString, args)
    }

    @inlinable
    public func debug(_ formatString: StaticString, _ args: CVarArg...) {
        log(.debug, formatString, args)
    }

    @inlinable
    public func info(_ formatString: StaticString, _ args: CVarArg...) {
        log(.info, formatString, args)
    }

    @inlinable
    public func error(_ formatString: StaticString, _ args: CVarArg...) {
        log(.error, formatString, args)
    }

    @inlinable
    public func fault(_ formatString: StaticString, _ args: CVarArg...) {
        log(.fault, formatString, args)
    }

}
