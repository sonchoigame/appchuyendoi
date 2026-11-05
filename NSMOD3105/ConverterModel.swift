import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let patch3105 = UTType(importedAs: "com.nsmod.patch3105", conformingTo: .data)
}

struct PatchDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.patch3105] }
    static var writableContentTypes: [UTType] { [.patch3105] }

    var data: Data
    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else {
            throw PatchFailure.message("File không có dữ liệu.")
        }
        data = contents
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

@MainActor final class ConverterModel: ObservableObject {
    @Published private(set) var fileName = ""
    @Published private(set) var rawFile: Data?
    @Published var sourcePassword: String = "" { didSet { invalidate() } }
    @Published private(set) var loaded: PatchCodec.Opened?
    @Published var selectedOldID = ""
    @Published var newID = ""
    @Published var status = "Chưa chọn file .3105"
    @Published var errorMessage: String?

    private func invalidate() {
        loaded = nil
        selectedOldID = ""
        status = rawFile == nil ? "Chưa chọn file .3105" : "Nhấn ĐỌC FILE để xác minh mật khẩu"
    }

    func importFile(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            guard url.pathExtension.lowercased() == "3105" else {
                throw PatchFailure.message("Hãy chọn file có đuôi .3105.")
            }
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size > 0, size <= PatchCodec.maximumSize else {
                throw PatchFailure.message("File phải nhỏ hơn hoặc bằng 512 MB.")
            }
            let raw = try Data(contentsOf: url, options: .mappedIfSafe)
            guard raw.count <= PatchCodec.maximumSize else {
                throw PatchFailure.message("File quá lớn.")
            }
            rawFile = raw
            fileName = url.lastPathComponent
            loaded = nil
            selectedOldID = ""
            newID = ""
            status = "Đã chọn file. Nhập mật khẩu gốc rồi nhấn ĐỌC FILE."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func read() {
        guard let rawFile else {
            errorMessage = "Chưa chọn file .3105."
            return
        }
        do {
            let value = try PatchCodec.open(rawFile, password: sourcePassword)
            loaded = value
            selectedOldID = value.bundles.first ?? ""
            status = "Đã giải mã • Schema \(value.schema) • \(value.ruleCount) file patch"
            errorMessage = nil
        } catch {
            loaded = nil
            selectedOldID = ""
            errorMessage = error.localizedDescription
        }
    }

    func createDocument() throws -> PatchDocument {
        guard let loaded else {
            throw PatchFailure.message("Cần nhấn ĐỌC FILE trước khi chuyển đổi.")
        }
        let bytes = try PatchCodec.export(loaded, old: selectedOldID, new: newID.trimmingCharacters(in: .whitespacesAndNewlines))
        return PatchDocument(data: bytes)
    }

    var outputName: String {
        let base = (fileName as NSString).deletingPathExtension
        return base + "_NSMOD"
    }
}
