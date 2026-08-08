import SwiftUI

struct PlexSetupPage: View {
    @ObservedObject var model: AppModel

    var body: some View {
        PlexSetupContent(model: model)
    }
}

struct JellyfinSetupPage: View {
    @ObservedObject var model: AppModel

    var body: some View {
        JellyfinSetupContent(model: model)
    }
}
