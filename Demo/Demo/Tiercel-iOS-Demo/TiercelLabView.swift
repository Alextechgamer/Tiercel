import CryptoKit
import Foundation
import SwiftUI
import Tiercel

/// Isolated diagnostic app using Tiercel 3.3.0 unchanged download semantics.
/// Own bundle ID/cache, not Carry's storage, queue, or background session.
@MainActor final class TiercelLabModel: ObservableObject {
    static let testURL = URL(string: "https://speed.cloudflare.com/__down?bytes=1048576")!
    static let testName = "Tiercel-Background-1MiB.bin"

    let manager: SessionManager
    @Published var currentStatus = "Ready"
    @Published var receivedBytes: Int64 = 0
    @Published var expectedBytes: Int64 = 1_048_576
    @Published var errorCode = "—"
    @Published var checksum = "—"
    @Published var finalFileBytes: Int64?
    @Published var trace = "Awaiting a test"
    @Published var busy = false

    init() {
        var settings = SessionConfiguration()
        settings.allowsCellularAccess = true
        settings.allowsConstrainedNetworkAccess = true
        settings.allowsExpensiveNetworkAccess = true
        settings.maxConcurrentTasksLimit = 1
        // Tiercel composes the background session identifier from bundle ID.
        // Files and persisted task metadata live in this app's separate sandbox.
        let documents = FileManager.default.urls(for: .documentDirectory,
                                                  in: .userDomainMask)[0]
        let tests = documents.appendingPathComponent("TiercelLabTests", isDirectory: true)
        let cache = Cache("CarryTiercelLab01", downloadPath: tests.path)
        manager = SessionManager("carry-tiercel-diagnostic-v1",
                                 configuration: settings, cache: cache)
        refresh()
    }

    var fraction: Double? {
        guard expectedBytes > 0 else { return nil }
        return min(1, max(0, Double(receivedBytes) / Double(expectedBytes)))
    }

    var isActive: Bool {
        manager.tasks.contains { $0.status == .running || $0.status == .waiting }
    }

    func refresh() {
        guard let task = manager.tasks.first else {
            currentStatus = "Ready"
            trace = "No test yet"
            receivedBytes = 0
            return
        }
        capture(task)
        // Reattach UI callbacks to recovered tasks after a process restart.
        task.progress { [weak self] result in
            DispatchQueue.main.async { [weak self] in self?.capture(result) }
        }.completion { [weak self] result in
            DispatchQueue.main.async { [weak self] in self?.capture(result) }
        }
    }

    private func sanitized(_ error: Error?) -> String {
        guard let error else { return "—" }
        let ns = error as NSError
        let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError
        return "\(ns.domain) [\(ns.code)]" +
            (underlying.map { " / \($0.domain) [\($0.code)]" } ?? "")
    }

    private func capture(_ task: DownloadTask) {
        receivedBytes = max(0, task.progress.completedUnitCount)
        if task.progress.totalUnitCount > 0 {
            expectedBytes = task.progress.totalUnitCount
        }
        currentStatus = task.status.rawValue.capitalized
        errorCode = sanitized(task.error)
        trace = task.status == .succeeded ? "Tiercel reported success"
              : task.status == .failed ? "Tiercel reported failure"
              : "Tiercel task \(task.status.rawValue)"
        if task.status == .succeeded {
            do {
                let file = URL(fileURLWithPath: task.filePath)
                let data = try Data(contentsOf: file)
                finalFileBytes = Int64(data.count)
                checksum = SHA256.hash(data: data).map { String(format:"%02x", $0) }.joined()
                if data.count == 1_048_576 {
                    trace = "File exists: 1 MiB saved, SHA-256 calculated."
                } else {
                    trace = "Tiercel reported success but file size did not match 1 MiB."
                }
            } catch {
                finalFileBytes = nil
                trace = "Tiercel reported success but file could not be read (code \((error as NSError).code))."
            }
        }
        busy = isActive
        saveSimulatorReceipt()
    }

    /// Debug Simulator-only receipt for independent, non-visual integration tests.
    private func saveSimulatorReceipt() {
        #if DEBUG && targetEnvironment(simulator)
        guard ProcessInfo.processInfo.environment["TIERCEL_LAB_AUTORUN"] == "1" else { return }
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let output = documents.appendingPathComponent("TiercelLab-Simulator-Result.json")
        let fields: [String: Any] = [
            "status": currentStatus,
            "receivedBytes": receivedBytes,
            "expectedBytes": expectedBytes,
            "savedFileBytes": finalFileBytes ?? -1,
            "sha256": checksum,
            "errorCode": errorCode,
            "diagnostic": trace
        ]
        if let data = try? JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]) {
            try? data.write(to: output, options: .atomic)
        }
        #endif
    }

    func start() {
        if isActive {
            trace = "A test is already running."
            return
        }
        if !manager.tasks.isEmpty {
            trace = "Test exists. Inspect its result or explicitly reset it before retrying."
            return
        }
        errorCode = "—"
        finalFileBytes = nil
        checksum = "—"
        receivedBytes = 0
        expectedBytes = 1_048_576
        currentStatus = "Submitting"
        trace = "Waiting for iOS to begin the background transfer."
        busy = true
        guard let task = manager.download(Self.testURL, fileName: Self.testName) else {
            currentStatus = "Submission failed"
            trace = "Tiercel could not create a task."
            busy = false
            return
        }
        task.progress { [weak self] changed in
            DispatchQueue.main.async { [weak self] in self?.capture(changed) }
        }.completion { [weak self] changed in
            DispatchQueue.main.async { [weak self] in self?.capture(changed) }
        }
        capture(task)
    }

    func reset() {
        guard !isActive else {
            trace = "Wait until the active test finishes before clearing its record."
            return
        }
        // Only delete the synthetic 1 MiB test within this isolated sandbox.
        if let task = manager.tasks.first {
            manager.remove(task, completely: true) { [weak self] _ in
                DispatchQueue.main.async { self?.refresh() }
            }
        }
        receivedBytes = 0
        expectedBytes = 1_048_576
        finalFileBytes = nil
        checksum = "—"
        errorCode = "—"
        trace = "Test record reset by user."
        currentStatus = "Ready"
    }
}

struct TiercelLabView: View {
    @ObservedObject var model: TiercelLabModel
    @State private var confirmReset = false
    private var sessionDisplay: String {
        #if targetEnvironment(simulator)
        return "Simulator in-process URLSession (not background daemon)"
        #else
        return "Physical iPhone background URLSession"
        #endif
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Independent background download") {
                    Text("Tiercel 3.3.0 · isolated 1 MiB public HTTPS file")
                        .font(.subheadline)
                    Button("Start 1 MiB Tiercel test", systemImage: "arrow.down.circle") {
                        model.start()
                    }
                    .disabled(model.busy || !model.manager.tasks.isEmpty)
                    if let fraction = model.fraction {
                        ProgressView(value: fraction)
                    }
                    LabeledContent("Status", value: model.currentStatus)
                    LabeledContent("Received",
                                   value: ByteCountFormatter.string(
                                     fromByteCount: model.receivedBytes, countStyle: .file))
                    LabeledContent("Expected",
                                   value: ByteCountFormatter.string(
                                     fromByteCount: model.expectedBytes, countStyle: .file))
                    if let length = model.finalFileBytes {
                        LabeledContent("Saved file",
                                       value: ByteCountFormatter.string(
                                         fromByteCount: length, countStyle: .file))
                    }
                    Text(model.trace).font(.footnote).foregroundStyle(.secondary)
                    if !model.manager.tasks.isEmpty {
                        Button("Clear this lab test", systemImage: "trash", role: .destructive) {
                            confirmReset = true
                        }.disabled(model.busy)
                    }
                }
                Section("Sanitized diagnostics") {
                    LabeledContent("Error", value: model.errorCode)
                    Text("SHA-256 (saved file)")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(model.checksum)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                    LabeledContent("Session", value: sessionDisplay)
                    Text("Full bytes transferred does not mean a file was saved. Success requires the saved file to exist and have the expected length.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("What this proves") {
                    Text("Tiercel uses Apple's system background download service, like Carry. If both fail with -3000 at 100%, switching libraries alone cannot solve the problem. If Tiercel completes, compare its session and file handling with Carry before integration.")
                    Text("Only 1 MiB is downloaded. No websites, login accounts, copyrighted files, Carry records, or prior downloads are accessed.")
                }
            }
            .navigationTitle("Tiercel Lab")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { model.refresh() }
            .confirmationDialog("Delete the lab test?", isPresented: $confirmReset) {
                Button("Delete only test file and record", role: .destructive) {
                    model.reset()
                }
            } message: {
                Text("Clears only the 1 MiB test in Tiercel Lab's own app sandbox.")
            }
        }
    }
}
