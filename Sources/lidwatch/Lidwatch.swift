import ArgumentParser

@main
struct Lidwatch: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "lidwatch",
        abstract: "Prevent idle sleep while AI agents are active",
        version: "0.1.0",
        subcommands: [Wrap.self, Status.self, Check.self, Watch.self]
    )
}
