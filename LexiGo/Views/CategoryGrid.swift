import SwiftUI

// MARK: - 首页分类网格

struct CategoryGrid: View {
    @ObservedObject var vm: FlashcardVM
    @State private var filterIndex: Int = 0

    private let filters = ["All", "New", "Done"]

    private var filteredCategories: [CategoryDef] {
        let all = CategoryDef.all
        switch filterIndex {
        case 1: return all.filter { !vm.learnedCategories.contains($0.id) }
        case 2: return all.filter { vm.learnedCategories.contains($0.id) }
        default: return all
        }
    }

    private func wordCount(for cat: CategoryDef) -> Int {
        WordDatabase.shared.words(for: cat.id).count
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题 + 星星
            HStack {
                Text("LexiGo")
                    .font(.bubbleFont(size: 40, relativeTo: .largeTitle))
                    .foregroundColor(Color(hex: "4A4E69"))

                Spacer()

                // 星星计数器
                HStack(spacing: 8) {
                    Text("🫧")
                        .font(.system(size: 28))
                    Text("\(vm.stars)")
                        .font(.bubbleFont(size: 32, relativeTo: .title))
                        .foregroundColor(Color(hex: "FF85B3"))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .padding(.bottom, 8)

            // 筛选栏
            HStack(spacing: 8) {
                ForEach(0..<filters.count, id: \.self) { i in
                    Text(filters[i])
                        .font(.bubbleFont(size: 16, relativeTo: .subheadline))
                        .foregroundColor(filterIndex == i ? .white : Color(hex: "4A4E69"))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(filterIndex == i ? Color(hex: "4A4E69") : .white.opacity(0.7))
                                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                        )
                        .onTapGesture {
                            Haptic.light.play()
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                filterIndex = i
                            }
                        }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 16)
                ], spacing: 16) {
                    ForEach(Array(filteredCategories.enumerated()), id: \.element.id) { index, cat in
                        CategoryCard(
                            cat: cat,
                            isLearned: vm.learnedCategories.contains(cat.id),
                            wordCount: wordCount(for: cat)
                        )
                        .popIn(delay: Double(index) * 0.04)
                        .onTapGesture {
                            Haptic.light.play()
                            vm.selectCategory(cat.id)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }

            AdBannerView(adUnitID: AdMobManager.shared.bannerAdUnitID)
                .frame(height: 50)
        }
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - 单个分类卡片

struct CategoryCard: View {
    let cat: CategoryDef
    let isLearned: Bool
    let wordCount: Int

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 8) {
                // 图标凹坑
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.25))
                        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.3), lineWidth: 1.5)
                        )

                    Text(cat.icon)
                        .font(.system(size: 42))
                        .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 2)
                }
                .frame(width: 80, height: 80)

                Text(cat.name)
                    .font(.bubbleFont(size: 20, relativeTo: .headline))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                // 词数提示
                Text("\(wordCount) words")
                    .font(.bubbleFont(size: 12, relativeTo: .caption))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 150)
            .background(
                RoundedRectangle(cornerRadius: 30)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: cat.theme.gradient),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 8)
            )
            .overlay(
                // 顶部高光
                RoundedRectangle(cornerRadius: 30)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.white.opacity(0.5), .clear]),
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                    .allowsHitTesting(false)
            )
            .opacity(isLearned ? 0.75 : 1)
            .saturation(isLearned ? 0.6 : 1)

            // 已学标志
            if isLearned {
                VStack(spacing: 0) {
                    Text("✅")
                        .font(.system(size: 24))
                        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 2)
                    Text("Done")
                        .font(.bubbleFont(size: 10, relativeTo: .caption2))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.black.opacity(0.3)))
                }
                .offset(x: 2, y: -2)
            }

            // 底部进度条：已学类别显示绿色条
            if isLearned {
                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: "9CE32D").opacity(0.8))
                        .frame(height: 4)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
            }
        }
        .contentShape(Rectangle())
    }
}
