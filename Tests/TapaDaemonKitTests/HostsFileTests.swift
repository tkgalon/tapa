import TapaCore
@testable import TapaDaemonKit
import Testing

struct HostsFileTests {
    let systemDefault = """
        ##
        # Host Database
        ##
        127.0.0.1\tlocalhost
        ::1             localhost

        """

    let reddit = DomainName("reddit.com")!
    let tiktok = DomainName("tiktok.com")!

    func block(_ domains: DomainName...) -> String {
        var lines = ["# TAPA BEGIN"]
        for host in domains.flatMap(\.hostsEntries) {
            lines += ["0.0.0.0 \(host)", ":: \(host)"]
        }
        return (lines + ["# TAPA END"]).joined(separator: "\n") + "\n"
    }

    @Test func appendsBlockAfterUserLines() {
        let rendered = HostsFile(contents: systemDefault).rendered(blocking: [tiktok, reddit])
        #expect(rendered == systemDefault + "\n" + block(reddit, tiktok))
    }

    @Test func replacesExistingBlock() {
        let blocked = HostsFile(contents: systemDefault).rendered(blocking: [reddit])
        let rendered = HostsFile(contents: blocked).rendered(blocking: [tiktok])
        #expect(rendered == systemDefault + "\n" + block(tiktok))
    }

    @Test func removingAllDomainsRestoresTheOriginal() {
        let blocked = HostsFile(contents: systemDefault).rendered(blocking: [reddit])
        #expect(HostsFile(contents: blocked).rendered(blocking: []) == systemDefault)
    }

    @Test func leavesAFileWithoutABlockUntouchedWhenNothingIsBlocked() {
        let unusual = "127.0.0.1 localhost\n\n\n# no trailing newline"
        #expect(HostsFile(contents: unusual).rendered(blocking: []) == unusual)
    }

    @Test func renderingIsIdempotent() {
        let once = HostsFile(contents: systemDefault).rendered(blocking: [reddit, tiktok])
        #expect(HostsFile(contents: once).rendered(blocking: [reddit, tiktok]) == once)
    }

    @Test func keepsUserLinesWrittenAfterTheBlock() {
        let contents = systemDefault + "\n" + block(reddit) + "10.0.0.5 nas.local\n"
        let rendered = HostsFile(contents: contents).rendered(blocking: [reddit])
        #expect(rendered == systemDefault + "\n10.0.0.5 nas.local\n\n" + block(reddit))
    }

    @Test func unterminatedBlockKeepsUserLines() {
        let damaged = systemDefault + "# TAPA BEGIN\n0.0.0.0 reddit.com\n10.0.0.5 nas.local\n"
        let rendered = HostsFile(contents: damaged).rendered(blocking: [])
        #expect(rendered == systemDefault + "10.0.0.5 nas.local\n")
    }

    @Test func strayEndMarkerIsRemoved() {
        let rendered = HostsFile(contents: systemDefault + "# TAPA END\n").rendered(blocking: [])
        #expect(rendered == systemDefault)
    }
}
