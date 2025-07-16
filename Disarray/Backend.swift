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

// The main data container no longer stores messages.
struct AppData: Codable {
    var servers: [Server]
    var channels: [UUID: [Channel]] // Key: Server ID
}


// --- Local Data Service ---
// Handles saving and loading data. Message logs are now in separate files.
class LocalDataService {
    private let appDataURL: URL
    private let logsURL: URL
    private var appData: AppData

    init() {
        // Find a place to store our data files in the user's Application Support directory.
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportURL = urls[0].appendingPathComponent("Disarray")
        
        // Create the main directory
        try? FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        
        // Define paths for the main data file and a new "Logs" sub-folder
        self.appDataURL = appSupportURL.appendingPathComponent("data.json")
        self.logsURL = appSupportURL.appendingPathComponent("Logs")
        
        // Create the "Logs" directory
        try? FileManager.default.createDirectory(at: logsURL, withIntermediateDirectories: true)
        
        // Try to load existing metadata, or create default data if none exists.
        if let data = try? Data(contentsOf: appDataURL),
           let decodedData = try? JSONDecoder().decode(AppData.self, from: data) {
            self.appData = decodedData
        } else {
            // If no file exists, create some default data to start with.
            self.appData = LocalDataService.createDefaultData(logsURL: logsURL)
            saveAppData()
        }
    }
    
    // Saves only the app metadata (servers and channels).
    private func saveAppData() {
        do {
            let data = try JSONEncoder().encode(appData)
            try data.write(to: appDataURL, options: .atomic)
        } catch {
            print("Error saving app data: \(error.localizedDescription)")
        }
    }
    
    // --- Public API for accessing data ---
    
    func getServers() -> [Server] {
        return appData.servers
    }
    
    func getChannels(for serverId: UUID) -> [Channel] {
        return appData.channels[serverId] ?? []
    }
    
    // This function now reads from a specific channel's log file.
    func getMessages(for channelId: UUID) -> [Message] {
        let channelLogURL = logsURL.appendingPathComponent("\(channelId).json")
        guard let data = try? Data(contentsOf: channelLogURL),
              let messages = try? JSONDecoder().decode([Message].self, from: data) else {
            return []
        }
        return messages.sorted(by: { $0.timestamp < $1.timestamp })
    }
    
    // This function now writes to a specific channel's log file.
    func sendMessage(_ message: Message, inChannel channelId: UUID) {
        var messages = getMessages(for: channelId)
        messages.append(message)
        
        let channelLogURL = logsURL.appendingPathComponent("\(channelId).json")
        do {
            let data = try JSONEncoder().encode(messages)
            try data.write(to: channelLogURL, options: .atomic)
        } catch {
            print("Error saving message for channel \(channelId): \(error.localizedDescription)")
        }
    }
    
    func addChannel(_ channel: Channel, toServer serverId: UUID) {
        appData.channels[serverId, default: []].append(channel)
        saveAppData()
    }
    
    // Helper function to create initial data for first-time launch
    static private func createDefaultData(logsURL: URL) -> AppData {
        let server1 = Server(name: "Local Gaming", iconName: "gamecontroller.fill")
        let server2 = Server(name: "My Projects", iconName: "hammer.fill")
        
        let channel1 = Channel(name: "general")
        let channel2 = Channel(name: "dev-log")
        
        // Create and save a default message to its own log file.
        let message1 = Message(author: "System", content: "Welcome! Each channel now has its own log file.", timestamp: Date())
        let initialMessages = [message1]
        if let data = try? JSONEncoder().encode(initialMessages) {
            let logURL = logsURL.appendingPathComponent("\(channel1.id).json")
            try? data.write(to: logURL)
        }
        
        // Return the metadata to be saved in the main data.json file.
        return AppData(
            servers: [server1, server2],
            channels: [server1.id: [channel1], server2.id: [channel2]]
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
    
    // Handles the logic for adding a new channel.
    func addChannel(named name: String) {
        guard let serverId = selectedServer?.id else { return }
        let newChannel = Channel(name: name)
        
        // 1. Save the new channel to the backend service.
        backend.addChannel(newChannel, toServer: serverId)
        
        // 2. Update the UI state directly by appending to the local array.
        channels.append(newChannel)
        
        // 3. Automatically select the new channel.
        selectedChannel = newChannel
    }
}
