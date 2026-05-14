import SwiftUI

// MARK: - 闪卡学习页

struct FlashcardView: View {
    @ObservedObject var vm: FlashcardVM
    @State private var showingConfetti = false
    @State private var transitionDirection: Int = 1 // 1=前进, -1=后退

    var body: some View {
        VStack(spacing: 0) {
            // 顶部栏
            topBar

            Spacer()

            // 主卡片
            mainCard
                .padding(.horizontal, 24)

            Spacer()

            // 底部分页 + 控制按钮
            bottomControls
                .padding(.bottom, 30)
        }
        .ignoresSafeArea()
        .background(
            ConfettiContainer(showing: $showingConfetti)
        )
        .task(id: vm.currentIndex) {
            // 切换卡片时自动播放发音
            try? await Task.sleep(nanoseconds: 400_000_000) // 等转场动画稳定
            vm.autoSpeak()
        }
    }

    // MARK: - 顶部栏

    private var topBar: some View {
        HStack {
            Button(action: { vm.goHome() }) {
                Text("🏠")
                    .font(.system(size: 32))
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .fill(.white)
                            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 4)
                    )
            }

            Spacer()

            // 分类名称 + 进度
            HStack(spacing: 8) {
                Text(vm.currentCategoryName)
                    .font(.bubbleFont(size: 24, relativeTo: .title2))
                    .foregroundColor(Color(hex: "4A4E69"))

                Text(vm.wordProgressText)
                    .font(.bubbleFont(size: 16, relativeTo: .subheadline))
                    .foregroundColor(Color(hex: "9CE32D"))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.white.opacity(0.8))
                    .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
            )

            Spacer()

            // 筛选切换 + Quiz
            HStack(spacing: 8) {
                Button(action: { vm.toggleShowOnlyNew() }) {
                    Text(vm.showOnlyNew ? "🔄 New" : "🔄 All")
                        .font(.bubbleFont(size: 16, relativeTo: .subheadline))
                        .foregroundColor(vm.showOnlyNew ? Color(hex: "9CE32D") : Color(hex: "4A4E69"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(.white.opacity(0.8))
                                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                        )
                }

                Button(action: { vm.startQuiz() }) {
                    Text("🎮")
                        .font(.system(size: 28))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(Color(hex: "FFD15C"))
                                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 4)
                                .overlay(
                                    Capsule()
                                        .fill(LinearGradient(
                                            gradient: Gradient(colors: [.white.opacity(0.5), .clear]),
                                            startPoint: .top, endPoint: .center
                                        ))
                                )
                        )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 60)
    }

    // MARK: - 主卡片

    private var mainCard: some View {
        ZStack {
            // 卡片背景（不动）
            RoundedRectangle(cornerRadius: 50)
                .fill(.white.opacity(0.95))
                .shadow(color: .black.opacity(0.05), radius: 20, x: 0, y: 15)
                .overlay(
                    RoundedRectangle(cornerRadius: 50)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.white.opacity(0.8), .clear]),
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                )

            // 卡片内容（切换时滑动进出）
            cardContentView
        }
        .frame(maxHeight: UIScreen.main.bounds.height * 0.55)
        .clipped()
        .onTapGesture {
            Haptic.light.play()
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                vm.revealWord()
            }
            // 如果已经揭示，再点就是复习发音
            if vm.wordRevealed {
                triggerMiniConfetti()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.width < -50 {
                        transitionDirection = 1
                        Haptic.medium.play()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            vm.nextCard()
                        }
                    } else if value.translation.width > 50 {
                        transitionDirection = -1
                        Haptic.medium.play()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            vm.prevCard()
                        }
                    }
                }
        )
    }

    private var cardContentView: some View {
        VStack(spacing: 16) {
            // 图片
            if let word = vm.currentWord, let image = word.loadImage() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.35)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 6)
                    .padding(.top, 20)
                    .transition(.opacity.combined(with: .scale))
            } else {
                // 占位图
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color(hex: "E8E0F0").opacity(0.4))
                    .frame(height: 200)
                    .overlay(
                        Text("🖼️")
                            .font(.system(size: 80))
                    )
                    .padding(.top, 20)
            }

            // 单词（初始隐藏，点击揭示）
            if let word = vm.currentWord {
                Text(word.display)
                    .font(.bubbleFont(size: vm.wordRevealed ? 64 : 48, relativeTo: .largeTitle))
                    .foregroundColor(Color(hex: "6366F1").opacity(vm.wordRevealed ? 1 : 0.3))
                    .scaleEffect(vm.wordRevealed ? 1.0 : 0.5)
                    .opacity(vm.wordRevealed ? 1.0 : 0.0)
                    .padding(.bottom, 8)
            }

            if !vm.wordRevealed {
                Text("Tap the bubble ✨")
                    .font(.bubbleFont(size: 20, relativeTo: .body))
                    .foregroundColor(Color(hex: "6366F1").opacity(0.4))
                    .padding(.bottom, 20)
            }
        }
        .padding(20)
        .overlay(alignment: .topTrailing) {
            // 已学标记
            if vm.isCurrentWordLearned {
                Text("✅")
                    .font(.system(size: 32))
                    .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
                    .padding(12)
            }
        }
        .id(vm.currentWord?.id ?? "none")
        .transition(.asymmetric(
            insertion: .move(edge: transitionDirection > 0 ? .trailing : .leading)
                .combined(with: .opacity),
            removal: .move(edge: transitionDirection > 0 ? .leading : .trailing)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.85))
        ))
    }

    // MARK: - 底部控制

    private var bottomControls: some View {
        VStack(spacing: 16) {
            // 导航按钮
            HStack(spacing: 16) {
                // 上一张
                navButton(icon: "◀", color: Color(hex: "60D0FF")) {
                    transitionDirection = -1
                    Haptic.light.play()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        vm.prevCard()
                    }
                }

                // 标记当前词已学/未学
                navButton(
                    icon: vm.isCurrentWordLearned ? "✅" : "📝",
                    color: vm.isCurrentWordLearned ? Color(hex: "9CE32D") : Color(hex: "B6A2FF")
                ) {
                    Haptic.medium.play()
                    vm.toggleWordLearned()
                }

                // 慢速听
                navButton(icon: "🐌", color: Color(hex: "60D0FF")) {
                    Haptic.light.play()
                    vm.autoSpeak()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        vm.slowSpeak()
                    }
                }

                // 听发音
                GummyButton(label: "🔊", color: Color(hex: "FF85B3")) {
                    vm.revealWord()
                }

                // 下一张
                navButton(icon: "▶", color: Color(hex: "60D0FF")) {
                    transitionDirection = 1
                    Haptic.light.play()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        vm.nextCard()
                    }
                }
            }

            // 进度 + 全部学完
            HStack(spacing: 12) {
                // 进度
                HStack(spacing: 6) {
                    Text("📖")
                        .font(.system(size: 18))
                    Text("\(vm.wordProgressText) learned")
                        .font(.bubbleFont(size: 18, relativeTo: .subheadline))
                        .foregroundColor(Color(hex: "4A4E69"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                )

                // 标记分类完成
                Button(action: {
                    let wasDone = vm.isCurrentCategoryLearned
                    Haptic.medium.play()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        vm.toggleCategoryLearned()
                    }
                    if !wasDone {
                        Haptic.success.play()
                        triggerConfetti()
                    }
                }) {
                    HStack(spacing: 6) {
                        Text(vm.isCurrentCategoryLearned ? "✅" : "⭐")
                            .font(.system(size: 18))
                        Text("Done All")
                            .font(.bubbleFont(size: 18, relativeTo: .subheadline))
                            .foregroundColor(vm.isCurrentCategoryLearned ? .white : Color(hex: "4A4E69"))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(vm.isCurrentCategoryLearned ? Color(hex: "9CE32D") : .white)
                            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 4)
                    )
                }
            }
        }
    }

    private func navButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
        }) {
            Text(icon)
                .font(.system(size: 32))
                .frame(width: 64, height: 64)
                .background(
                    Circle()
                        .fill(color)
                        .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 4)
                        .overlay(
                            Circle()
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [.white.opacity(0.5), .clear]),
                                    startPoint: .top, endPoint: .center
                                ))
                        )
                )
        }
        .buttonStyle(GummyButtonStyle())
    }

    // MARK: - Confetti

    private func triggerMiniConfetti() {
        showingConfetti = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showingConfetti = false
        }
    }

    private func triggerConfetti() {
        showingConfetti = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showingConfetti = false
        }
    }
}

// MARK: - 简易撒花容器

struct ConfettiContainer: UIViewRepresentable {
    @Binding var showing: Bool

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard showing else { return }
        showConfetti(in: uiView)
    }

    private func showConfetti(in view: UIView) {
        let layer = makeEmitterLayer(for: view)
        let cell = makeStarCell()
        let cell2 = makeCircleCell()
        layer.emitterCells = [cell, cell2]

        view.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        view.layer.addSublayer(layer)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { layer.birthRate = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            view.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        }
    }

    private func makeEmitterLayer(for view: UIView) -> CAEmitterLayer {
        let layer = CAEmitterLayer()
        layer.emitterPosition = CGPoint(x: view.bounds.midX, y: -20)
        layer.emitterShape = .line
        layer.emitterSize = CGSize(width: view.bounds.width, height: 1)
        return layer
    }

    private func makeStarCell() -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = makeStarImage()?.cgImage
        cell.birthRate = 8
        cell.lifetime = 3.0
        cell.velocity = 200
        cell.velocityRange = 80
        cell.emissionLongitude = .pi
        cell.emissionRange = .pi / 4
        cell.scale = 0.15
        cell.scaleRange = 0.1
        cell.spin = 4
        cell.spinRange = 2
        cell.color = UIColor(red: 1, green: 0.85, blue: 0.36, alpha: 1).cgColor
        return cell
    }

    private func makeCircleCell() -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = makeCircleImage()?.cgImage
        cell.birthRate = 6
        cell.lifetime = 2.5
        cell.velocity = 180
        cell.velocityRange = 60
        cell.emissionLongitude = .pi
        cell.emissionRange = .pi / 4
        cell.scale = 0.12
        cell.scaleRange = 0.08
        cell.spin = 3
        cell.spinRange = 2
        cell.color = UIColor(red: 0.38, green: 0.82, blue: 1, alpha: 1).cgColor
        return cell
    }

    private func makeStarImage() -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20))
        let image: UIImage = renderer.image { ctx in
            ctx.cgContext.setFillColor(UIColor.yellow.cgColor)
            let path = UIBezierPath()
            let center = CGPoint(x: 10, y: 10)
            for i in 0..<5 {
                let angle: Double = Double(i) * 2 * .pi / 5 - .pi / 2
                let ox: CGFloat = center.x + cos(angle) * 8
                let oy: CGFloat = center.y + sin(angle) * 8
                if i == 0 { path.move(to: CGPoint(x: ox, y: oy)) }
                else { path.addLine(to: CGPoint(x: ox, y: oy)) }
                let innerAngle: Double = angle + .pi / 5
                let ix: CGFloat = center.x + cos(innerAngle) * 3.5
                let iy: CGFloat = center.y + sin(innerAngle) * 3.5
                path.addLine(to: CGPoint(x: ix, y: iy))
            }
            path.close()
            ctx.cgContext.addPath(path.cgPath)
            ctx.cgContext.fillPath()
        }
        return image
    }

    private func makeCircleImage() -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16))
        let image: UIImage = renderer.image { ctx in
            ctx.cgContext.setFillColor(UIColor(red: 1, green: 0.52, blue: 0.7, alpha: 1).cgColor)
            ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: 16, height: 16))
        }
        return image
    }
}
