//
//  ContentView.swift
//  Disarray
//
//  Created by Patch on 16/07/2025.
//

import SwiftUI

// --- Main View ---
struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()

    var body: some View {
        NavigationSplitView {
            ServerListView(servers: viewModel.servers, selectedServer: $viewModel.selectedServer)
        } content: {
            if let server = viewModel.selectedServer {
                 // We now pass the viewModel into the ChannelListView
                 ChannelListView(viewModel: viewModel, channels: viewModel.channels, selectedChannel: $viewModel.selectedChannel)
                    .navigationTitle(server.name)
            } else {
                Text("Select a Server")
                    .foregroundColor(.secondary)
            }
        } detail: {
            if let channel = viewModel.selectedChannel {
                ChatView(viewModel: viewModel, channel: channel)
            } else {
                Text("Select a Channel")
                    .foregroundColor(.secondary)
                    .navigationTitle("")
            }
        }
    }
}


// --- UI Components ---
struct ServerListView: View {
    let servers: [Server]
    @Binding var selectedServer: Server?

    var body: some View {
        List(servers, selection: $selectedServer) { server in
            HStack {
                Image(systemName: server.iconName)
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.blue.gradient)
                    .clipShape(Circle())
                Text(server.name)
            }
            .padding(.vertical, 4)
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        .navigationTitle("Servers")
    }
}

struct ChannelListView: View {
    @ObservedObject var viewModel: ChatViewModel // Needs the viewModel to call functions
    let channels: [Channel]
    @Binding var selectedChannel: Channel?
    
    @State private var showingAddChannelSheet = false
    @State private var newChannelName = ""

    var body: some View {
        List(channels, selection: $selectedChannel) { channel in
            HStack {
                Image(systemName: "number")
                Text(channel.name)
            }
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddChannelSheet = true }) {
                    Label("Add Channel", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddChannelSheet) {
            AddChannelView(isPresented: $showingAddChannelSheet, channelName: $newChannelName) {
                if !newChannelName.isEmpty {
                    viewModel.addChannel(named: newChannelName)
                    newChannelName = "" // Reset for next time
                }
            }
        }
    }
}

// A new view for the "Add Channel" input sheet
struct AddChannelView: View {
    @Binding var isPresented: Bool
    @Binding var channelName: String
    var onCreate: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Create New Channel")
                .font(.headline)
            
            TextField("Channel Name", text: $channelName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Create") {
                    onCreate()
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(channelName.isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 300, idealWidth: 350)
    }
}


struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    let channel: Channel
    @State private var newMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageRowView(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages) {
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            HStack {
                TextField("Message #\(channel.name)", text: $newMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit(sendMessage)
                Button("Send", action: sendMessage)
                    .disabled(newMessage.isEmpty)
            }
            .padding()
            .background(.bar)
        }
        .navigationTitle("# \(channel.name)")
    }
    
    private func sendMessage() {
        guard !newMessage.isEmpty else { return }
        viewModel.sendMessage(content: newMessage, author: "LocalUser")
        newMessage = ""
    }
}

struct MessageRowView: View {
    let message: Message
    
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "person.crop.circle.fill")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading) {
                HStack(alignment: .firstTextBaseline) {
                    Text(message.author)
                        .fontWeight(.bold)
                    Text(message.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(message.content)
            }
        }
    }
}


// --- Preview ---
#Preview {
    ContentView()
}

