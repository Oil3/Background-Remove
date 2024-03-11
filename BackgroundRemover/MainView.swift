//
//  MainView.swift
import SwiftUI

struct MainView: View {
@StateObject private var pipeline = EffectsPipeline()

    
    var body: some View {
        TabView {
            ContentGifView()
                .tabItem {
                Label("GIF", systemImage: "tray.and.arrow.down.fill")}
                
            ContentMovieView()
                .tabItem {
                Label("Movies", systemImage: "tray.and.arrow.up.fill")}
            
            ContentView()
                .environmentObject(pipeline)
                .tabItem {
                Label("Pictures", systemImage: "tray.and.arrow.down.fill")}
        }
    }
}
//
//struct MainView_Previews: PreviewProvider {
//    static var previews: some View {
//        MainView()
//    }
//}
//
