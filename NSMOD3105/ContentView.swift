import SwiftUI
import UniformTypeIdentifiers

private enum Theme {
    static let background = Color(red: 0.035, green: 0.060, blue: 0.114)
    static let panel = Color(red: 0.083, green: 0.116, blue: 0.187)
    static let border = Color.white.opacity(0.095)
    static let accent = Color(red: 0.20, green: 0.69, blue: 1.0)
    static let muted = Color(red: 0.60, green: 0.68, blue: 0.78)
}

private struct GlowCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Theme.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Theme.border, lineWidth: 1)
                    )
            )
    }
}

private struct TapScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private struct PrimaryButton: View {
    let text: String
    let icon: String
    var disabled: Bool = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                Text(text)
                    .fontWeight(.bold)
                Spacer(minLength: 0)
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .bold))
            }
            .font(.system(size: 15))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 18)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: disabled ? [Color.gray, Color.gray] :
                        [Theme.accent, Color(red: 0.10, green: 0.38, blue: 0.88)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 16)
            )
        }
        .buttonStyle(TapScale())
        .disabled(disabled)
        .opacity(disabled ? 0.55 : 1)
    }
}

private enum Page: String, CaseIterable, Identifiable {
    case home = "Trang chủ"
    case convert = "Chuyển đổi"
    case settings = "Cài đặt"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .home: return "square.grid.2x2.fill"
        case .convert: return "arrow.left.arrow.right"
        case .settings: return "gearshape.fill"
        }
    }
}

struct ContentView: View {
    @StateObject private var model = ConverterModel()
    @AppStorage("nsmod_has_opened_telegram") private var openedTelegram = false
    @Environment(\.scenePhase) private var phase
    @State private var page: Page = .home
    @State private var showWelcome = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            RadialGradient(
                colors: [Theme.accent.opacity(0.12), .clear],
                center: .topTrailing, startRadius: 20, endRadius: 420
            ).ignoresSafeArea()

            NavigationStack {
                Group {
                    switch page {
                    case .home:
                        HomeScreen(onConvert: {
                            withAnimation(.easeInOut(duration: 0.22)) { page = .convert }
                        })
                    case .convert:
                        ConverterScreen(model: model)
                    case .settings:
                        SettingsScreen()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
                .toolbar(.hidden, for: .navigationBar)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                HStack(spacing: 3) {
                    ForEach(Page.allCases) { item in
                        Button {
                            withAnimation(.easeInOut(duration: 0.20)) { page = item }
                        } label: {
                            VStack(spacing: 5) {
                                Image(systemName: item.symbol).font(.system(size: 18, weight: .semibold))
                                Text(item.rawValue).font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(page == item ? Theme.accent : Theme.muted)
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            .background(page == item ? Theme.accent.opacity(0.10) : .clear,
                                        in: RoundedRectangle(cornerRadius: 15))
                        }.buttonStyle(.plain)
                    }
                }
                .padding(7)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.border))
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            }

            if showWelcome {
                Color.black.opacity(0.74).ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(2)
                WelcomePopup(canClose: openedTelegram, openTelegram: {
                    openedTelegram = true
                    UIApplication.shared.open(AppLinks.telegram)
                }, dismiss: {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                        showWelcome = false
                    }
                })
                .padding(.horizontal, 24)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.86).combined(with: .opacity),
                    removal: .scale(scale: 0.96).combined(with: .opacity)
                ))
                .zIndex(3)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.85)) { showWelcome = true }
        }
        .onChange(of: phase) { value in
            if value == .active {
                withAnimation(.spring(response: 0.48, dampingFraction: 0.85)) {
                    showWelcome = true
                }
            }
        }
    }
}

private struct Header: View {
    let subtitle: String
    var body: some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 43, height: 43)
                    .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 2) {
                    Text("NSMOD").font(.system(size: 23, weight: .black, design: .rounded))
                        .tracking(1.3)
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(Theme.muted)
                }
            }
            Spacer()
            Text("3105")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .foregroundStyle(Theme.accent)
                .background(Theme.accent.opacity(0.11), in: Capsule())
        }
        .foregroundStyle(.white)
    }
}

private struct HomeScreen: View {
    let onConvert: () -> Void
    @Environment(\.openURL) private var openURL
    @State private var pulse = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Header(subtitle: "OFFICIAL IOS UTILITY")
                    .padding(.top, 12)

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NEXT GEN TOOL")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(2.1)
                                .foregroundStyle(Theme.accent)
                            Text("Chuyển đổi\nfile .3105")
                                .font(.system(size: 31, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Đổi Bundle ID an toàn • Giữ nguyên dữ liệu patch")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        ZStack {
                            Circle()
                                .stroke(Theme.accent.opacity(0.28), lineWidth: 1.5)
                                .frame(width: 78, height: 78)
                                .scaleEffect(pulse ? 1.2 : 0.86)
                                .opacity(pulse ? 0.3 : 0.8)
                            Circle()
                                .fill(Theme.accent.opacity(0.12))
                                .frame(width: 82, height: 82)
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 31, weight: .medium))
                                .foregroundStyle(Theme.accent)
                                .rotationEffect(.degrees(pulse ? 360 : 0))
                        }
                        .frame(width: 92)
                    }
                    PrimaryButton(text: "BẮT ĐẦU CHUYỂN ĐỔI", icon: "arrow.left.arrow.right", action: onConvert)
                }
                .modifier(GlowCard())
                .padding(.top, 5)

                VStack(alignment: .leading, spacing: 11) {
                    Text("KHÁM PHÁ NSMOD")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.8)
                        .foregroundStyle(Theme.muted)
                    HStack(spacing: 10) {
                        HomeLink(symbol: "globe", title: "Web Crack", detail: "Trang chủ", tint: Theme.accent) {
                            openURL(AppLinks.webCrack)
                        }
                        HomeLink(symbol: "paperplane.fill", title: "Telegram", detail: "Kênh chính", tint: Color(red: 0.30, green: 0.77, blue: 1)) {
                            openURL(AppLinks.telegram)
                        }
                    }
                    HomeLink(symbol: "play.rectangle.fill", title: "TikTok", detail: "@pettersiuto", tint: Color(red: 1, green: 0.35, blue: 0.54)) {
                        openURL(AppLinks.tikTok)
                    }
                }

                Text("Built for precision  •  NSMOD")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 19)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            pulse = false
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

private struct HomeLink: View {
    let symbol: String
    let title: String
    let detail: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 42, height: 42)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                    Text(detail).font(.system(size: 11)).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            .modifier(GlowCard())
        }
        .buttonStyle(TapScale())
    }
}

private struct ConverterScreen: View {
    @ObservedObject var model: ConverterModel
    @State private var showImporter = false
    @State private var showExporter = false
    @State private var document: PatchDocument?
    @FocusState private var passwordFocused: Bool
    @FocusState private var bundleFocused: Bool

    private func dismissKeyboard() {
        passwordFocused = false
        bundleFocused = false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Header(subtitle: "3105 BUNDLE CONVERTER")
                    .padding(.top, 12)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Chuyển đổi 3105")
                        .font(.system(size: 27, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Đọc file • Đổi Bundle ID • Xuất bản mới")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                }

                VStack(alignment: .leading, spacing: 15) {
                    fieldLabel("01  TỆP PATCH .3105")
                    Button {
                        dismissKeyboard()
                        showImporter = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.zipper")
                                .font(.system(size: 20))
                                .foregroundStyle(Theme.accent)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(model.fileName.isEmpty ? "Chọn file .3105" : model.fileName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .lineLimit(2)
                                    .foregroundStyle(.white)
                                Text("Chạm để mở ứng dụng Tệp")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Image(systemName: "folder")
                                .foregroundStyle(Theme.accent)
                        }
                        .padding(14)
                        .background(Theme.background.opacity(0.72),
                                    in: RoundedRectangle(cornerRadius: 13))
                    }
                    .buttonStyle(TapScale())

                    fieldLabel("02  MẬT KHẨU GỐC")
                    SecureField("Mật khẩu của member", text: $model.sourcePassword)
                        .focused($passwordFocused)
                        .submitLabel(.done)
                        .onSubmit(dismissKeyboard)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .modifier(InputStyle())
                    PrimaryButton(text: "ĐỌC FILE VÀ XÁC MINH", icon: "lock.open.fill",
                                  disabled: model.fileName.isEmpty) {
                        dismissKeyboard()
                        model.read()
                    }
                    HStack(spacing: 7) {
                        Image(systemName: model.loaded == nil ? "info.circle" : "checkmark.seal.fill")
                            .foregroundStyle(model.loaded == nil ? Theme.muted : .green)
                        Text(model.status)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.muted)
                    }
                }.modifier(GlowCard())

                VStack(alignment: .leading, spacing: 15) {
                    fieldLabel("03  BUNDLE ID HIỆN TẠI")
                    Menu {
                        ForEach(model.loaded?.bundles ?? [], id: \.self) { bundle in
                            Button(bundle) { model.selectedOldID = bundle }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(model.selectedOldID.isEmpty ? "Đọc file trước" : model.selectedOldID)
                                .font(.system(size: 13, design: .monospaced))
                                .lineLimit(1).truncationMode(.middle)
                                .foregroundStyle(model.loaded == nil ? Theme.muted : .white)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.accent)
                        }
                        .modifier(InputStyle())
                    }
                    .disabled(model.loaded == nil)

                    fieldLabel("04  BUNDLE ID MỚI")
                    TextField("Ví dụ: com.kgvn.nsmod", text: $model.newID)
                        .focused($bundleFocused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit(dismissKeyboard)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.white)
                        .modifier(InputStyle())

                    Text("Chỉ đổi thư mục Bundle ID đầu tiên. Giữ nguyên Documents/, Library/, đường dẫn và dữ liệu.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    PrimaryButton(text: "XUẤT FILE .3105 MỚI", icon: "square.and.arrow.up.fill",
                                  disabled: model.loaded == nil || model.newID.isEmpty) {
                        dismissKeyboard()
                        do {
                            document = try model.createDocument()
                            showExporter = true
                        } catch {
                            model.errorMessage = error.localizedDescription
                        }
                    }
                    HStack {
                        Image(systemName: "lock.shield.fill")
                        Text("Mật khẩu file xuất: nsmod")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                }.modifier(GlowCard())
            }
            .padding(.horizontal, 19)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(Color.clear.contentShape(Rectangle()).onTapGesture(perform: dismissKeyboard))
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Xong", action: dismissKeyboard)
                    .fontWeight(.semibold)
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.patch3105, .data]) { result in
            switch result {
            case .success(let url):
                model.importFile(url)
            case .failure(let error):
                model.errorMessage = error.localizedDescription
            }
        }
        .fileExporter(isPresented: $showExporter, document: $document,
                      contentType: .patch3105, defaultFilename: model.outputName) { result in
            if case .failure(let error) = result {
                model.errorMessage = error.localizedDescription
            }
        }
        .alert("NSMOD", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("Đóng", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .tracking(1.1)
            .foregroundStyle(Theme.muted)
    }
}

private struct InputStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(Theme.background.opacity(0.8), in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.border))
    }
}

private struct SettingsScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Header(subtitle: "ABOUT THE APP").padding(.top, 12)
                VStack(spacing: 14) {
                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(Theme.accent)
                        .padding(.top, 14)
                    Text("NSMOD")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Được phát triển bởi NSMOD")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Một công cụ nhỏ, một trải nghiệm gọn gàng.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                    Divider().overlay(Theme.border)
                    HStack {
                        Text("Phiên bản").foregroundStyle(Theme.muted)
                        Spacer()
                        Text("1.0.0").foregroundStyle(.white)
                    }.font(.system(size: 13))
                }
                .frame(maxWidth: .infinity)
                .modifier(GlowCard())
                Spacer()
            }
            .padding(.horizontal, 19)
        }
        .scrollIndicators(.hidden)
    }
}

private struct WelcomePopup: View {
    let canClose: Bool
    let openTelegram: () -> Void
    let dismiss: () -> Void
    @State private var float = false

    var body: some View {
        VStack(spacing: 17) {
            ZStack {
                Circle().fill(Theme.accent.opacity(0.11)).frame(width: 90, height: 90)
                    .scaleEffect(float ? 1.15 : 0.92)
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 39, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .offset(y: float ? -3 : 3)
            }
            .frame(height: 92)
            Text("NSMOD COMMUNITY")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(.white)
            Text("Tham gia kênh Telegram chính thức để nhận cập nhật, thông báo và các bản phát hành mới.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryButton(text: "VÀO KÊNH TELEGRAM", icon: "paperplane.fill",
                          action: openTelegram)
            if canClose {
                Button(action: dismiss) {
                    Text("ĐÓNG")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 49)
                        .background(Theme.background, in: RoundedRectangle(cornerRadius: 15))
                        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Theme.border))
                }
                .buttonStyle(TapScale())
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            Text("NSMOD  •  OFFICIAL")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.7)
                .foregroundStyle(Theme.muted)
        }
        .padding(24)
        .frame(maxWidth: 420)
        .background(
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.10, green: 0.16, blue: 0.26), Theme.panel],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .overlay(RoundedRectangle(cornerRadius: 27).stroke(Theme.accent.opacity(0.24)))
        )
        .shadow(color: Theme.accent.opacity(0.12), radius: 35, y: 15)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                float = true
            }
        }
    }
}
