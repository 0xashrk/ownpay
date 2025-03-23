//
//  FriendPickerView.swift
//  Own Pay
//
//  Created by Ashwin Ravikumar on 23/03/2025.
//

import SwiftUI

struct FriendPickerView: View {
    @Binding var selectedFriend: Friend?
    @Binding var isPresented: Bool
    @State private var searchText = ""
    let onSendRequest: (Friend) -> Void
    
    @StateObject private var viewModel = FriendsViewModel()
    @Environment(\.colorScheme) var colorScheme
    
    private var surfaceColor: Color { colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.1) }
    
    var filteredFriends: [Friend] {
        if searchText.isEmpty {
            return viewModel.friends
        } else {
            return viewModel.friends.filter {
                $0.name.lowercased().contains(searchText.lowercased()) ||
                $0.username.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search friends", text: $searchText)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(surfaceColor)
            .cornerRadius(10)
            .padding()
            
            if viewModel.isLoading {
                ProgressView("Loading friends...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.red.opacity(0.5))
                        .padding()
                    
                    Text("Error loading friends")
                        .font(.headline)
                    
                    if let apiError = error as? APIError {
                        Text(apiError.localizedDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    } else {
                        Text("Unable to load friends. Please try again.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Button(action: {
                        viewModel.loadFriends()
                    }) {
                        Label("Retry", systemImage: "arrow.clockwise")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding()
            } else if filteredFriends.isEmpty {
                emptyFriendsView
            } else {
                // Friends list
                List {
                    ForEach(filteredFriends) { friend in
                        friendRow(friend: friend)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationTitle("Select Friend")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    isPresented = false
                }
            }
        }
        .onAppear {
            viewModel.loadFriends()
        }
    }
    
    private var emptyFriendsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3")
                .font(.system(size: 50))
                .foregroundColor(.secondary.opacity(0.5))
                .padding()
            
            if searchText.isEmpty {
                Text("No friends yet")
                    .font(.headline)
                
                Text("You haven't added any friends to request from")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button(action: {
                    // Action to add friends
                }) {
                    Label("Add Friends", systemImage: "person.badge.plus")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.top, 8)
            } else {
                Text("No matches found")
                    .font(.headline)
                
                Text("Try a different search term")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func friendRow(friend: Friend) -> some View {
        Button(action: {
            selectedFriend = friend
            onSendRequest(friend)
        }) {
            HStack(spacing: 16) {
                // Avatar image
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: friend.avatarName)
                        .font(.system(size: 24))
                        .foregroundColor(.purple)
                }
                
                // Friend info
                VStack(alignment: .leading, spacing: 4) {
                    Text(friend.name)
                        .font(.headline)
                    
                    Text(friend.username)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Direct request button
                Button(action: {
                    selectedFriend = friend
                    onSendRequest(friend)
                }) {
                    Text("Request")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
