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
                 ChannelListView(channels: viewModel.channels, selectedChannel: $viewModel.selectedChannel)
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
    let channels: [Channel]
    @Binding var selectedChannel: Channel?

    var body: some View {
        List(channels, selection: $selectedChannel) { channel in
            HStack {
                Image(systemName: "number")
                Text(channel.name)
            }
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 220)
    }
}

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    let channel: Channel
    @State private var newMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        MessageRowView(message: message)
                    }
                }
                .padding()
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
