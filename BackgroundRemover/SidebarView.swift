//
//  SideBarView.swift
import SwiftUI

struct SidebarView: View {
    // Binding variables to trigger actions in the ContentView
    @Binding var showFilePicker: Bool
    @Binding var showSavePanel: Bool
    @Binding var showFolderPicker: Bool
    @Binding var processingFolder: Bool
    
    var body: some View {
        List {
            Button("Choose from Files") {
                showFilePicker = true
            }

            Button("Save Result Image") {
                showSavePanel = true
            }

            Button("Process Folder") {
                showFolderPicker = true
            }
        }
        .listStyle(SidebarListStyle())
    }
}
