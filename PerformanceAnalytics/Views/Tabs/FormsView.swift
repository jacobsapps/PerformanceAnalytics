//
//  FormsView.swift
//  PerformanceAnalytics
//
//  Created by Jacob Bartlett on 21/07/2025.
//

import SwiftUI

struct FormsView: View {
    
    private let analyticsService: AnalyticsService
    
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var company = ""
    @State private var bio = ""
    @State private var isShowingSuccessAlert = false
    @State private var progressTrackingTask: Task<Void, Never>?
    
    init(analyticsService: AnalyticsService) {
        self.analyticsService = analyticsService
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Personal Information")) {
                    TextField("Full Name", text: $name)
                        .onChange(of: name) { _, _ in
                            trackFieldInteraction(field: "name")
                        }
                    
                    TextField("Email Address", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .onChange(of: email) { _, _ in
                            trackFieldInteraction(field: "email")
                        }
                    
                    TextField("Phone Number", text: $phone)
                        .keyboardType(.phonePad)
                        .onChange(of: phone) { _, _ in
                            trackFieldInteraction(field: "phone")
                        }
                }
                
                Section(header: Text("Address & Work")) {
                    TextField("Home Address", text: $address, axis: .vertical)
                        .lineLimit(2...4)
                        .onChange(of: address) { _, _ in
                            trackFieldInteraction(field: "address")
                        }
                    
                    TextField("Company", text: $company)
                        .onChange(of: company) { _, _ in
                            trackFieldInteraction(field: "company")
                        }
                }
                
                Section(header: Text("About You")) {
                    TextField("Bio", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                        .onChange(of: bio) { _, _ in
                            trackFieldInteraction(field: "bio")
                        }
                }
                
                Section {
                    Button(action: submitForm) {
                        HStack {
                            Spacer()
                            Text("Submit")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!isFormValid)
                    
                    Button(action: clearForm) {
                        HStack {
                            Spacer()
                            Text("Clear All")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
                
                Section(header: Text("Form Statistics")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Character Count:")
                            .font(.headline)
                        
                        HStack {
                            Text("Name:")
                            Spacer()
                            Text("\(name.count)")
                                .monospaced()
                        }
                        
                        HStack {
                            Text("Email:")
                            Spacer()
                            Text("\(email.count)")
                                .monospaced()
                        }
                        
                        HStack {
                            Text("Bio:")
                            Spacer()
                            Text("\(bio.count)")
                                .monospaced()
                        }
                        
                        HStack {
                            Text("Total Characters:")
                            Spacer()
                            Text("\(totalCharacterCount)")
                                .monospaced()
                                .fontWeight(.bold)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Forms")
        }
        .alert("Success!", isPresented: $isShowingSuccessAlert) {
            Button("OK") { }
        } message: {
            Text("Form submitted successfully!")
        }
        .onAppear {
            analyticsService.track(event: "Forms Tab - Viewed", properties: nil)
            startProgressTracking()
        }
        .onDisappear {
            stopProgressTracking()
        }
    }
    
    private var isFormValid: Bool {
        !name.isEmpty && !email.isEmpty && email.contains("@")
    }
    
    private var totalCharacterCount: Int {
        name.count + email.count + phone.count + address.count + company.count + bio.count
    }
    
    private func trackFieldInteraction(field: String) {
        analyticsService.track(event: "Form - Interaction", properties: [
            "field": field,
            "character_count": getFieldCharacterCount(field: field),
            "total_form_characters": totalCharacterCount,
            "form_completion_percentage": calculateCompletionPercentage()
        ])
    }
    
    private func getFieldCharacterCount(field: String) -> Int {
        switch field {
        case "name": return name.count
        case "email": return email.count
        case "phone": return phone.count
        case "address": return address.count
        case "company": return company.count
        case "bio": return bio.count
        default: return 0
        }
    }
    
    private func calculateCompletionPercentage() -> Double {
        var completedFields = 0
        let totalFields = 6
        
        if !name.isEmpty { completedFields += 1 }
        if !email.isEmpty { completedFields += 1 }
        if !phone.isEmpty { completedFields += 1 }
        if !address.isEmpty { completedFields += 1 }
        if !company.isEmpty { completedFields += 1 }
        if !bio.isEmpty { completedFields += 1 }
        
        return Double(completedFields) / Double(totalFields) * 100.0
    }
    
    private func submitForm() {
        analyticsService.track(event: "Form - Submitted", properties: [
            "total_characters": totalCharacterCount,
            "completion_percentage": calculateCompletionPercentage(),
            "fields_completed": [
                "name": !name.isEmpty,
                "email": !email.isEmpty,
                "phone": !phone.isEmpty,
                "address": !address.isEmpty,
                "company": !company.isEmpty,
                "bio": !bio.isEmpty
            ]
        ])
        
        isShowingSuccessAlert = true
    }
    
    private func clearForm() {
        analyticsService.track(event: "Form - Cleared", properties: [
            "previous_character_count": totalCharacterCount,
            "previous_completion_percentage": calculateCompletionPercentage()
        ])
        
        name = ""
        email = ""
        phone = ""
        address = ""
        company = ""
        bio = ""
    }
    
    private func startProgressTracking() {
        progressTrackingTask = Task.detached {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                if !Task.isCancelled {
                    await MainActor.run {
                        analyticsService.track(event: "Forms Tab - In Progress", properties: [
                            "form_valid": isFormValid,
                            "total_characters": totalCharacterCount,
                            "completion_percentage": calculateCompletionPercentage(),
                            "active_fields": [
                                "name": !name.isEmpty,
                                "email": !email.isEmpty,
                                "phone": !phone.isEmpty,
                                "address": !address.isEmpty,
                                "company": !company.isEmpty,
                                "bio": !bio.isEmpty
                            ]
                        ])
                    }
                }
            }
        }
    }
    
    private func stopProgressTracking() {
        progressTrackingTask?.cancel()
        progressTrackingTask = nil
    }
}
