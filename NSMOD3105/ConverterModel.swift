import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let patch3105 = UTType(importedAs: "com.nsmod.patch3105", conformingTo: .data)
}

struct PatchDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.patch3105, .data] }
    static var writableContentTypes: [UTType] { [.patch3105] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let content = configuration.file.regularFileContents else {
            throw PatchFailure.message("Không tìm thấy dữ liệu file.")
        }
        data = content
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

@MainActor final class ConverterModel: ObservableObject {
    @Published private(set) var fileName = ""
    @Published private(set) var rawFile: Data?
    @Published var sourcePassword: String = "" { didSet { invalidateDecoded() } }
    @Published private(set) var loaded: PatchCodec.Opened?
    @Published var selectedOldID = ""
    @Published var newID = ""
    @Published var status = "Chưa chọn file .3105"
    @Published var errorMessage: String?
    @Published var isImporting = false
    @Published var isReading = false
    @Published var isExporting = false
    @Published var exportDocument: PatchDocument?
    @Published var showExporter = false

    private var importToken = UUID()
    private var readToken = UUID()
    private var exportToken = UUID()

    var busy: Bool { isImporting || isReading || isExporting }

    private func invalidateDecoded() {
        readToken = UUID()
        exportToken = UUID()
        loaded = nil
        selectedOldID = ""
        exportDocument = nil
        showExporter = false
        isReading = false
        isExporting = false
        status = rawFile == nil ? "Chưa chọn file .3105" : "Nhấn ĐỌC FILE để xác minh mật khẩu"
    }

    /// Files picker returns a local copy. Reading happens off the main thread,
    /// so large patches do not freeze the Files sheet or converter interface.
    func importFile(_ url: URL) {
        guard url.pathExtension.lowercased() == "3105" else {
            errorMessage = "Hãy chọn tệp có đuôi .3105."
            return
        }
        importToken = UUID()
        let token = importToken
        fileName = url.lastPathComponent
        rawFile = nil
        invalidateDecoded()
        isImporting = true
        status = "Đang nhập file từ ứng dụng Tệp..."
        errorMessage = nil
        Task {
            do {
                let bytes = try await Task.detached(priority: .userInitiated) {
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size > 0 && size <= PatchCodec.maximumSize else {
                        throw PatchFailure.message("File rỗng hoặc lớn hơn 512 MB.")
                    }
                    // Do not use mmap: completely read while permission is held.
                    let value = try Data(contentsOf: url)
                    guard value.count <= PatchCodec.maximumSize else {
                        throw PatchFailure.message("Dung lượng file vượt quá giới hạn.")
                    }
                    return value
                }.value
                guard importToken == token else { return }
                rawFile = bytes
                isImporting = false
                status = "Đã nhập file. Nhập mật khẩu rồi nhấn ĐỌC FILE."
            } catch {
                guard importToken == token else { return }
                isImporting = false
                rawFile = nil
                errorMessage = "Không thể nhập file: \(error.localizedDescription)"
                status = "Nhập file thất bại"
            }
        }
    }

    func read() {
        guard let raw = rawFile else {
            errorMessage = "Hãy chọn file .3105 trước."
            return
        }
        let password = sourcePassword
        readToken = UUID()
        let token = readToken
        loaded = nil
        selectedOldID = ""
        isReading = true
        status = "Đang giải mã và kiểm tra checksum..."
        errorMessage = nil
        Task {
            do {
                let decoded = try await Task.detached(priority: .userInitiated) {
                    try PatchCodec.open(raw, password: password)
                }.value
                guard readToken == token else { return }
                loaded = decoded
                selectedOldID = decoded.bundles.first ?? ""
                isReading = false
                status = "Đã đọc • Schema \(decoded.schema) • \(decoded.ruleCount) file patch"
            } catch {
                guard readToken == token else { return }
                isReading = false
                status = "Không giải mã được file"
                errorMessage = error.localizedDescription
            }
        }
    }

    func prepareExport() {
        guard let loaded = loaded else {
            errorMessage = "Nhấn ĐỌC FILE trước khi chuyển đổi."
            return
        }
        let old = selectedOldID
        let new = newID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard PatchCodec.validBundleID(new), old != new else {
            errorMessage = "Bundle ID mới không hợp lệ hoặc trùng Bundle ID cũ."
            return
        }
        exportToken = UUID()
        let token = exportToken
        isExporting = true
        status = "Đang đổi Bundle ID và mã hóa lại..."
        errorMessage = nil
        Task {
            do {
                let bytes = try await Task.detached(priority: .userInitiated) {
                    try PatchCodec.export(loaded, old: old, new: new)
                }.value
                guard exportToken == token else { return }
                isExporting = false
                status = "Đã tạo file .3105 • Mật khẩu mới: nsmod"
                exportDocument = PatchDocument(data: bytes)
                showExporter = true
            } catch {
                guard exportToken == token else { return }
                isExporting = false
                status = "Không thể xuất file"
                errorMessage = error.localizedDescription
            }
        }
    }

    var outputName: String {
        let base = (fileName as NSString).deletingPathExtension
        return (base.isEmpty ? "NSMOD" : base) + "_NSMOD"
    }
}
