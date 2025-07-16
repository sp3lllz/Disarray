//
//  Server.swift
//  Disarray
//
//  Created by Patch on 16/07/2025.
//


import Foundation
import Combine

// --- Data Models (For Local Storage) ---
struct Server: Identifiable, Codable, Hashable {
    var id = UUID()
    let name: String
    let iconName: String
}

struct Channel: Identifiable, Codable, Hashable {
    var id = UUID()
    let name: String
}

struct Message: Identifiable, Codable, Hashable {
    var id = UUID()
    let author: String
    let content: String
    let timestamp: Date
}

// A single container for all app data to make JSON storage easy
struct AppData: Codable {
    var servers: [Server]
    var channels: [UUID: [Channel]] // Key: Server ID
    var messages: [UUID: [Message]] // Key: Channel ID
}


// --- Local Data Service ---
// Handles saving and loading all data to a local JSON file.
class LocalDataService {
    private let fileURL: URL
    private var appData: AppData

    init() {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportURL = urls[0].appendingPathComponent("Disarray")
        try? FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        self.fileURL = appSupportURL.appendingPathComponent("data.json")
        
        if let data = try? Data(contentsOf: fileURL),
           let decodedData = try? JSONDecoder().decode(AppData.self, from: data) {
            self.appData = decodedData
        } else {
            self.appData = LocalDataService.createDefaultData()
            saveData()
        }
    }
    
    private func saveData() {
        do {
            let data = try JSONEncoder().encode(appData)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Error saving data: \(error.localizedDescription)")
        }
    }
    
    // --- Public API ---
    func getServers() -> [Server] {
        return appData.servers
    }
    
    func getChannels(for serverId: UUID) -> [Channel] {
        return appData.channels[serverId] ?? []
    }
    
    func getMessages(for channelId: UUID) -> [Message] {
        return appData.messages[channelId]?.sorted(by: { $0.timestamp < $1.timestamp }) ?? []
    }
    
    func sendMessage(_ message: Message, inChannel channelId: UUID) {
        appData.messages[channelId, default: []].append(message)
        saveData()
    }
    
    static private func createDefaultData() -> AppData {
        let server1 = Server(name: "Local Gaming", iconName: "gamecontroller.fill")
        let server2 = Server(name: "My Projects", iconName: "hammer.fill")
        let channel1 = Channel(name: "general")
        let channel2 = Channel(name: "dev-log")
        let message1 = Message(author: "System", content: "Welcome! All data is now stored locally.", timestamp: Date())
        
        return AppData(
            servers: [server1, server2],
            channels: [server1.id: [channel1], server2.id: [channel2]],
            messages: [channel1.id: [message1]]
        )
    }
}


// --- ViewModel (Connects Backend to UI) ---
@MainActor
class ChatViewModel: ObservableObject {
    @Published var servers: [Server] = []
    @Published var channels: [Channel] = []
    @Published var messages: [Message] = []
    
    @Published var selectedServer: Server? {
        didSet { fetchChannels() }
    }
    @Published var selectedChannel: Channel? {
        didSet { fetchMessages() }
    }
    
    private let backend = LocalDataService()

    init() {
        fetchServers()
    }

    func fetchServers() {
        servers = backend.getServers()
        if selectedServer == nil {
            selectedServer = servers.first
        }
    }

    func fetchChannels() {
        guard let serverId = selectedServer?.id else {
            channels = []; return
        }
        channels = backend.getChannels(for: serverId)
        if !channels.contains(where: { $0.id == selectedChannel?.id }) {
            selectedChannel = channels.first
        }
    }
    
    func fetchMessages() {
        guard let channelId = selectedChannel?.id else {
            messages = []; return
        }
        messages = backend.getMessages(for: channelId)
    }
    
    func sendMessage(content: String, author: String) {
        guard let channelId = selectedChannel?.id else { return }
        let newMessage = Message(author: author, content: content, timestamp: Date())
        backend.sendMessage(newMessage, inChannel: channelId)
        messages.append(newMessage)
    }
}
