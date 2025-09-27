struct Secret {
    static var geminiKey: String? {
        KeychainHelper.shared.read(for: "otome_gemini_key")
    }
}