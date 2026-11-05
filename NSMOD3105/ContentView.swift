import SwiftUI
import UniformTypeIdentifiers
import UIKit

private enum NS {
    static let bg = Color(red: 0.025, green: 0.015, blue: 0.05)
    static let panel = Color(red: 0.073, green: 0.052, blue: 0.125)
    static let field = Color(red: 0.073, green: 0.066, blue: 0.13)
    static let purple = Color(red: 0.70, green: 0.36, blue: 1.0)
    static let bright = Color(red: 0.90, green: 0.67, blue: 1.0)
    static let muted = Color(red: 0.69, green: 0.67, blue: 0.78)
    static let edge = Color(red: 0.49, green: 0.31, blue: 0.70)
    static let gradient = LinearGradient(
        colors: [Color(red: 0.39, green: 0.17, blue: 0.78),
                 Color(red: 0.72, green: 0.30, blue: 0.97),
                 Color(red: 0.44, green: 0.19, blue: 0.86)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

private struct DarkBackdrop: View {
    var body: some View {
        ZStack {
            NS.bg
            RadialGradient(colors: [NS.purple.opacity(0.24), .clear],
                           center: .topTrailing, startRadius: 10, endRadius: 400)
            RadialGradient(colors: [NS.purple.opacity(0.11), .clear],
                           center: .bottomLeading, startRadius: 35, endRadius: 380)
        }
        .ignoresSafeArea()
    }
}

private struct NeonPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(NS.panel.opacity(0.96))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(NS.edge.opacity(0.70), lineWidth: 1.2)
                    }
                    .shadow(color: NS.purple.opacity(0.18), radius: 15, y: 5)
            }
    }
}

private struct NeonField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .background(NS.field, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(NS.edge.opacity(0.50), lineWidth: 1)
            }
    }
}

private struct NeonButton: View {
    let title: String
    let symbol: String
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(0.25)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 2)
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(enabled ? .white : NS.muted)
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(enabled ? NS.gradient : LinearGradient(colors: [NS.field, NS.panel],
                                                                 startPoint: .top, endPoint: .bottom))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(NS.bright.opacity(enabled ? 0.85 : 0.24), lineWidth: 1)
                    }
                    .shadow(color: NS.purple.opacity(enabled ? 0.40 : 0), radius: 13)
            }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

private struct LabelStep: View {
    let step: String
    let title: String
    var body: some View {
        HStack(spacing: 8) {
            Text(step)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(NS.gradient, in: RoundedRectangle(cornerRadius: 8))
            Text(title)
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.90))
        }
    }
}

private enum MainTab: String, CaseIterable, Identifiable {
    case home = "Trang chủ"
    case convert = "Chuyển đổi"
    case settings = "Cài đặt"
    var id: String { rawValue }
    var image: String {
        switch self {
        case .home: return "square.grid.2x2.fill"
        case .convert: return "arrow.left.arrow.right"
        case .settings: return "gearshape.fill"
        }
    }
}

struct ContentView: View {
    @StateObject private var model = ConverterModel()
    @AppStorage("nsmod_has_opened_telegram") private var visitedTelegram = false
    @State private var showWelcome = false
    @State private var welcomeShownThisLaunch = false
    @State private var selectedTab: MainTab = .convert

    var body: some View {
        ZStack {
            DarkBackdrop()
            Group {
                switch selectedTab {
                case .home:
                    HomeView(goConvert: { withAnimation(.easeInOut(duration: 0.22)) { selectedTab = .convert } })
                case .convert:
                    ConverterView(model: model)
                case .settings:
                    AboutView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomTabs }

            if showWelcome {
                Color.black.opacity(0.82).ignoresSafeArea()
                    .zIndex(2)
                    .transition(.opacity)
                WelcomeView(canClose: visitedTelegram,
                            openTelegram: {
                                withAnimation(.easeOut(duration: 0.2)) { visitedTelegram = true }
                                UIApplication.shared.open(Links.telegram)
                            },
                            close: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.84)) {
                                    showWelcome = false
                                }
                            })
                    .padding(.horizontal, 22)
                    .zIndex(3)
                    .transition(.scale(scale: 0.87).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            guard !welcomeShownThisLaunch else { return }
            welcomeShownThisLaunch = true
            withAnimation(.spring(response: 0.46, dampingFraction: 0.85)) {
                showWelcome = true
            }
        }
    }

    private var bottomTabs: some View {
        HStack(spacing: 4) {
            ForEach(MainTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.20)) { selectedTab = tab }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.image).font(.system(size: 19, weight: .semibold))
                        Text(tab.rawValue).font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(tab == selectedTab ? NS.bright : NS.muted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background {
                        if tab == selectedTab {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(NS.purple.opacity(0.25))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(NS.edge.opacity(0.7), lineWidth: 1)
                                }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(7)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(NS.panel.opacity(0.98))
                .overlay {
                    RoundedRectangle(cornerRadius: 26)
                        .stroke(NS.edge.opacity(0.53), lineWidth: 1)
                }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }
}

private enum Links {
    static let telegram = URL(string: "https://t.me/sonchoigame23")!
    static let tikTok = URL(string: "https://www.tiktok.com/@pettersiuto")!
    static let crack = URL(string: "https://nsmod.github.io/nsmodcrack")!
}

private struct BrandHeader: View {
    var body: some View {
        ZStack(alignment: .leading) {
            Image("HeaderArt")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .clipped()
                .overlay {
                    LinearGradient(colors: [NS.bg.opacity(0.87), NS.bg.opacity(0.22)],
                                   startPoint: .leading, endPoint: .trailing)
                }
            HStack(spacing: 10) {
                Image("NSMODLogo")
                    .resizable().aspectRatio(contentMode: .fill)
                    .frame(width: 65, height: 65).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 17))
                    .overlay {
                        RoundedRectangle(cornerRadius: 17).stroke(NS.bright, lineWidth: 1.5)
                    }
                    .shadow(color: NS.purple.opacity(0.48), radius: 9)
                VStack(alignment: .leading, spacing: 1) {
                    Text("NSMOD")
                        .font(.system(size: 32, weight: .black, design: .serif))
                        .tracking(0.3)
                        .foregroundStyle(.white)
                        .shadow(color: NS.purple, radius: 8)
                    Text("3105 BUNDLE CONVERTER")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.0)
                        .foregroundStyle(NS.bright)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
        }
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct ConverterView: View {
    @ObservedObject var model: ConverterModel
    @State private var showPicker = false
    @State private var passwordVisible = false
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case password, bundle }

    private func dismissKeyboard() { focusedField = nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                BrandHeader()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Chuyển Đổi File 3105")
                        .font(.system(size: 27, weight: .black, design: .rounded))
                        .minimumScaleFactor(0.78)
                        .lineLimit(1)
                        .foregroundStyle(.white)
                        .shadow(color: NS.purple.opacity(0.7), radius: 10)
                    Text("Đọc file • Đổi Bundle ID • Xuất bản mới")
                        .font(.system(size: 12))
                        .foregroundStyle(NS.muted)
                }
                .padding(.horizontal, 4)

                VStack(alignment: .leading, spacing: 15) {
                    LabelStep(step: "01", title: "TỆP PATCH .3105")
                    Button {
                        dismissKeyboard()
                        showPicker = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.zipper")
                                .font(.system(size: 25))
                                .foregroundStyle(NS.bright)
                                .frame(width: 35)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(model.fileName.isEmpty ? "Chọn file .3105" : model.fileName)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                Text("Chạm để mở ứng dụng Tệp")
                                    .font(.system(size: 11))
                                    .foregroundStyle(NS.muted)
                            }
                            Spacer()
                            Image(systemName: "folder")
                                .foregroundStyle(NS.bright)
                        }
                        .padding(13)
                        .background(NS.field, in: RoundedRectangle(cornerRadius: 15))
                        .overlay {
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(NS.edge.opacity(0.5), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(model.busy)

                    LabelStep(step: "02", title: "MẬT KHẨU GỐC")
                    HStack {
                        Image(systemName: "lock.fill").foregroundStyle(NS.muted)
                        Group {
                            if passwordVisible {
                                TextField("Nhập mật khẩu file .3105", text: $model.sourcePassword)
                            } else {
                                SecureField("Nhập mật khẩu file .3105", text: $model.sourcePassword)
                            }
                        }
                        .focused($focusedField, equals: .password)
                        .submitLabel(.done)
                        .onSubmit(dismissKeyboard)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        Button { passwordVisible.toggle() } label: {
                            Image(systemName: passwordVisible ? "eye" : "eye.slash")
                                .foregroundStyle(NS.muted)
                        }.buttonStyle(.plain)
                    }
                    .modifier(NeonField())

                    NeonButton(title: model.isReading ? "ĐANG GIẢI MÃ..." : "ĐỌC FILE VÀ LẤY THÔNG TIN",
                               symbol: "square.stack.3d.up.fill",
                               enabled: !model.busy && model.rawFile != nil) {
                        dismissKeyboard()
                        model.read()
                    }

                    LabelStep(step: "03", title: "BUNDLE ID GỐC")
                    Menu {
                        ForEach(model.loaded?.bundles ?? [], id: \.self) { bundle in
                            Button(bundle) { model.selectedOldID = bundle }
                        }
                    } label: {
                        HStack {
                            Text(model.selectedOldID.isEmpty ? "Đọc file trước để chọn Bundle ID" : model.selectedOldID)
                                .lineLimit(1).truncationMode(.middle)
                                .foregroundStyle(model.loaded == nil ? NS.muted : .white)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .foregroundStyle(NS.bright)
                        }
                        .font(.system(size: 13, design: .monospaced))
                        .modifier(NeonField())
                    }
                    .disabled(model.loaded == nil || model.busy)

                    LabelStep(step: "04", title: "BUNDLE ID MỚI")
                    HStack(spacing: 9) {
                        Image(systemName: "shippingbox.fill").foregroundStyle(NS.muted)
                        TextField("VD: com.nsmod.app", text: $model.newID)
                            .focused($focusedField, equals: .bundle)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .onSubmit(dismissKeyboard)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    .modifier(NeonField())
                    Text("Chỉ đổi Bundle ID đã chọn. Giữ nguyên Documents/, Library/ và tất cả nội dung patch.")
                        .font(.system(size: 11))
                        .foregroundStyle(NS.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    NeonButton(title: model.isExporting ? "ĐANG MÃ HÓA..." : "XUẤT FILE MỚI • PASS NSMOD",
                               symbol: "arrow.triangle.2.circlepath",
                               enabled: !model.busy && model.loaded != nil &&
                                        PatchCodec.validBundleID(model.newID.trimmingCharacters(in: .whitespacesAndNewlines)) &&
                                        model.newID != model.selectedOldID) {
                        dismissKeyboard()
                        model.prepareExport()
                    }
                    HStack(spacing: 7) {
                        if model.busy { ProgressView().tint(NS.bright) }
                        Image(systemName: "checkmark.shield.fill").foregroundStyle(NS.bright)
                        Text(model.status)
                            .font(.system(size: 11))
                            .foregroundStyle(NS.muted)
                            .lineLimit(3)
                    }
                }
                .modifier(NeonPanel())
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 15)
            .frame(maxWidth: 590)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .simultaneousGesture(TapGesture().onEnded { dismissKeyboard() })
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Xong", action: dismissKeyboard).fontWeight(.bold)
            }
        }
        .sheet(isPresented: $showPicker) {
            PatchFilePicker(onSelect: { url in
                showPicker = false
                model.importFile(url)
            }, onCancel: { showPicker = false })
            .ignoresSafeArea()
        }
        .fileExporter(isPresented: $model.showExporter, document: model.exportDocument,
                      contentType: .patch3105, defaultFilename: model.outputName) { result in
            if case .failure(let error) = result {
                model.errorMessage = error.localizedDescription
            }
            model.exportDocument = nil
        }
        .alert("NSMOD", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("Đóng", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }
}

private struct HomeView: View {
    let goConvert: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                BrandHeader()
                VStack(alignment: .leading, spacing: 10) {
                    Text("NSMOD • 3105 CONVERTER")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(1.5)
                        .foregroundStyle(NS.bright)
                    Text("Chuyển đổi Bundle ID\nnhanh chóng, chính xác.")
                        .font(.system(size: 25, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Giữ nguyên dữ liệu và đường dẫn của patch. File mới có mật khẩu nsmod.")
                        .font(.system(size: 13))
                        .foregroundStyle(NS.muted)
                    NeonButton(title: "BẮT ĐẦU CHUYỂN ĐỔI", symbol: "arrow.left.arrow.right",
                               action: goConvert)
                }
                .modifier(NeonPanel())

                Text("KHÁM PHÁ NSMOD")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.6)
                    .foregroundStyle(NS.bright)
                    .padding(.leading, 5)
                resource("globe", "WEB CRACK", "nsmod.github.io/nsmodcrack") { openURL(Links.crack) }
                resource("paperplane.fill", "TELEGRAM", "@sonchoigame23") { openURL(Links.telegram) }
                resource("play.rectangle.fill", "TIKTOK", "@pettersiuto") { openURL(Links.tikTok) }
            }
            .padding(.horizontal, 15)
            .frame(maxWidth: 590)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private func resource(_ symbol: String, _ title: String, _ subtitle: String,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 22))
                    .foregroundStyle(NS.bright)
                    .frame(width: 44, height: 44)
                    .background(NS.purple.opacity(0.16), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 14, weight: .heavy)).foregroundStyle(.white)
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(NS.muted)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(NS.bright)
            }
            .modifier(NeonPanel())
        }
        .buttonStyle(.plain)
    }
}

private struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 40)
            Image("NSMODLogo")
                .resizable().aspectRatio(contentMode: .fill)
                .frame(width: 108, height: 108).clipped()
                .clipShape(RoundedRectangle(cornerRadius: 25))
                .overlay(RoundedRectangle(cornerRadius: 25).stroke(NS.bright, lineWidth: 1))
                .shadow(color: NS.purple.opacity(0.60), radius: 18)
            Text("NSMOD")
                .font(.system(size: 33, weight: .black, design: .serif))
                .foregroundStyle(.white)
            Text("Được phát triển bởi NSMOD")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(NS.bright)
            Text("Một công cụ nhỏ, một trải nghiệm gọn gàng.")
                .font(.system(size: 12))
                .foregroundStyle(NS.muted)
                .multilineTextAlignment(.center)
            Text("Phiên bản 1.3.0")
                .font(.system(size: 11))
                .foregroundStyle(NS.muted)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct WelcomeView: View {
    let canClose: Bool
    let openTelegram: () -> Void
    let close: () -> Void
    @State private var floating = false

    var body: some View {
        VStack(spacing: 16) {
            Image("NSMODLogo")
                .resizable().aspectRatio(contentMode: .fill)
                .frame(width: 92, height: 92).clipped()
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(NS.bright, lineWidth: 1.5))
                .shadow(color: NS.purple.opacity(0.6), radius: 18)
                .offset(y: floating ? -4 : 4)
            Text("NSMOD COMMUNITY")
                .font(.system(size: 20, weight: .black, design: .serif))
                .foregroundStyle(.white)
            Text("Tham gia kênh Telegram chính thức để nhận thông báo, cập nhật và phiên bản mới.")
                .font(.system(size: 13))
                .foregroundStyle(NS.muted)
                .multilineTextAlignment(.center)
            NeonButton(title: "VÀO KÊNH TELEGRAM", symbol: "paperplane.fill", action: openTelegram)
            if canClose {
                Button(action: close) {
                    Text("ĐÓNG")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(NS.field, in: RoundedRectangle(cornerRadius: 15))
                        .overlay(RoundedRectangle(cornerRadius: 15)
                            .stroke(NS.edge.opacity(0.7), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            Text("NSMOD • OFFICIAL")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(NS.muted)
        }
        .modifier(NeonPanel())
        .frame(maxWidth: 430)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                floating = true
            }
        }
    }
}
