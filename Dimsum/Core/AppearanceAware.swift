private let appearanceOffset = 0.07

func adaptedIntensity(base: Double, isDarkMode: Bool) -> Double {
    let offset = isDarkMode ? -appearanceOffset : appearanceOffset
    return (base + offset).clamped(to: 0.1...0.8)
}
