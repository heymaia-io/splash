import Foundation

/// `GET /actuator/info` — Komga build, runtime and host details.
///
/// Spring Boot's actuator payload is deeply nested and its sections are all optional (a server can
/// disable any of them), so this flattens only the parts worth showing and makes every field optional.
/// Requires the ADMIN role; other users get 403 and the screen simply omits the section.
public struct KomgaServerInfo: Codable, Hashable, Sendable {
    public var version: String?
    public var buildName: String?
    public var gitBranch: String?
    public var gitCommitId: String?
    public var gitCommitTime: Date?
    public var javaVersion: String?
    public var javaVendor: String?
    public var osName: String?
    public var osVersion: String?
    public var osArch: String?

    public init(
        version: String? = nil, buildName: String? = nil, gitBranch: String? = nil,
        gitCommitId: String? = nil, gitCommitTime: Date? = nil, javaVersion: String? = nil,
        javaVendor: String? = nil, osName: String? = nil, osVersion: String? = nil, osArch: String? = nil
    ) {
        self.version = version
        self.buildName = buildName
        self.gitBranch = gitBranch
        self.gitCommitId = gitCommitId
        self.gitCommitTime = gitCommitTime
        self.javaVersion = javaVersion
        self.javaVendor = javaVendor
        self.osName = osName
        self.osVersion = osVersion
        self.osArch = osArch
    }

    private enum BuildKeys: String, CodingKey { case name, version }
    private enum GitKeys: String, CodingKey { case branch, commit }
    private enum CommitKeys: String, CodingKey { case id, time }
    private enum JavaKeys: String, CodingKey { case version, vendor }
    private enum VendorKeys: String, CodingKey { case name }
    private enum OSKeys: String, CodingKey { case name, version, arch }
    private enum RootKeys: String, CodingKey { case build, git, java, os }

    public init(from decoder: Decoder) throws {
        let root = try decoder.container(keyedBy: RootKeys.self)
        let build = try? root.nestedContainer(keyedBy: BuildKeys.self, forKey: .build)
        version = try build?.decodeIfPresent(String.self, forKey: .version)
        buildName = try build?.decodeIfPresent(String.self, forKey: .name)

        let git = try? root.nestedContainer(keyedBy: GitKeys.self, forKey: .git)
        gitBranch = try git?.decodeIfPresent(String.self, forKey: .branch)
        let commit = try? git?.nestedContainer(keyedBy: CommitKeys.self, forKey: .commit)
        gitCommitId = try commit?.decodeIfPresent(String.self, forKey: .id)
        gitCommitTime = try commit?.decodeIfPresent(Date.self, forKey: .time)

        let java = try? root.nestedContainer(keyedBy: JavaKeys.self, forKey: .java)
        javaVersion = try java?.decodeIfPresent(String.self, forKey: .version)
        let vendor = try? java?.nestedContainer(keyedBy: VendorKeys.self, forKey: .vendor)
        javaVendor = try vendor?.decodeIfPresent(String.self, forKey: .name)

        let os = try? root.nestedContainer(keyedBy: OSKeys.self, forKey: .os)
        osName = try os?.decodeIfPresent(String.self, forKey: .name)
        osVersion = try os?.decodeIfPresent(String.self, forKey: .version)
        osArch = try os?.decodeIfPresent(String.self, forKey: .arch)
    }
}
