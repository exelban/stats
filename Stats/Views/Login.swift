//
//  Login.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 16/03/2025
//  Using Swift 6.0
//  Running on macOS 15.3
//
//  Copyright © 2025 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

internal class LoginWindow: NSWindow, NSWindowDelegate {
    private let viewController: LoginViewController = LoginViewController()
    
    init() {
        super.init(
            contentRect: NSRect(
                x: NSScreen.main!.frame.width - self.viewController.view.frame.width,
                y: NSScreen.main!.frame.height - self.viewController.view.frame.height,
                width: self.viewController.view.frame.width,
                height: self.viewController.view.frame.height
            ),
            styleMask: [.closable, .titled],
            backing: .buffered,
            defer: true
        )
        
        self.title = localizedString("Stats Remote")
        self.contentViewController = self.viewController
        self.titlebarAppearsTransparent = true
        self.positionCenter()
        self.setIsVisible(false)
        
        let windowController = NSWindowController()
        windowController.window = self
        windowController.loadWindow()
    }
    
    internal func open() {
        guard !self.isVisible else { return }
        self.setIsVisible(true)
        self.makeKeyAndOrderFront(nil)
    }
    
    private func positionCenter() {
        self.setFrameOrigin(NSPoint(
            x: (NSScreen.main!.frame.width - self.viewController.view.frame.width)/2,
            y: (NSScreen.main!.frame.height - self.viewController.view.frame.height)/1.75
        ))
    }
}

private class LoginViewController: NSViewController {
    private var _view: LoginView
    
    public init() {
        self._view = LoginView(frame: NSRect(x: 0, y: 0, width: 320, height: 170))
        super.init(nibName: nil, bundle: nil)
        self.view = self._view
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private class LoginView: NSView {
    private let stackView: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .centerX
        return stack
    }()
    
    private let formStack: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        return stack
    }()
    
    private let usernameTextField: NSTextField = {
        let textField = NSTextField()
        textField.placeholderString = localizedString("Username")
        textField.bezelStyle = .roundedBezel
        textField.font = .systemFont(ofSize: 13)
        if #available(macOS 11.0, *) {
            textField.controlSize = .large
        }
        return textField
    }()
    
    private let passwordTextField: NSSecureTextField = {
        let textField = NSSecureTextField()
        textField.placeholderString = localizedString("Password")
        textField.bezelStyle = .roundedBezel
        textField.font = .systemFont(ofSize: 13)
        if #available(macOS 11.0, *) {
            textField.controlSize = .large
        }
        return textField
    }()
    
    private let loginButton: NSButton = {
        let button = NSButton(title: localizedString("Login"), target: nil, action: #selector(loginButtonTapped))
        button.bezelStyle = .rounded
        if #available(macOS 11.0, *) {
            button.controlSize = .large
        }
        button.font = .systemFont(ofSize: 13, weight: .semibold)
        button.keyEquivalent = "\r"
        return button
    }()
    
    private let registerStack: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 5
        return stack
    }()
    
    private let registerLabel: NSTextField = {
        let label = NSTextField(labelWithString: localizedString("Don't have an account?"))
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        return label
    }()
    
    private let registerButton: NSButton = {
        let button = NSButton(title: localizedString("Register here"), target: nil, action: #selector(registerButtonTapped))
        button.bezelStyle = .inline
        button.font = .systemFont(ofSize: 12)
        button.contentTintColor = .systemBlue
        return button
    }()
    
    private let errorLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.textColor = .systemRed
        label.font = .systemFont(ofSize: 12)
        label.alignment = .center
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        return label
    }()
    
    override init(frame: NSRect) {
        super.init(frame: CGRect(x: frame.origin.x, y: frame.origin.y, width: frame.width, height: frame.height))
        self.wantsLayer = true
        
        let sidebar = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height))
        sidebar.material = .sidebar
        sidebar.blendingMode = .behindWindow
        sidebar.state = .active
        
        self.addSubview(sidebar)
        self.setupLayout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupLayout() {
        self.formStack.addArrangedSubview(self.usernameTextField)
        self.formStack.addArrangedSubview(self.passwordTextField)
        self.formStack.addArrangedSubview(self.errorLabel)
        
        self.registerStack.addArrangedSubview(self.registerLabel)
        self.registerStack.addArrangedSubview(self.registerButton)
        
        self.stackView.addArrangedSubview(self.formStack)
        self.stackView.addArrangedSubview(self.loginButton)
//        self.stackView.addArrangedSubview(self.registerStack)
        
        addSubview(self.stackView)
        self.stackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            self.stackView.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            self.stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            self.stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            self.formStack.widthAnchor.constraint(equalTo: self.stackView.widthAnchor),
            self.loginButton.widthAnchor.constraint(equalToConstant: 100)
        ])
        
        self.loginButton.target = self
        self.registerButton.target = self
    }
    
    @objc private func loginButtonTapped() {
        let username = self.usernameTextField.stringValue.trimmingCharacters(in: .whitespaces)
        let password = self.passwordTextField.stringValue
        
        guard username.count >= 3 else {
            showError("Username must be at least 3 characters")
            return
        }
        guard username.count <= 30 else {
            self.showError("Username must be less than 30 characters")
            return
        }
        
        guard password.count >= 6 else {
            self.showError("Password must be at least 6 characters")
            return
        }
        guard password.count <= 50 else {
            self.showError("Password must be less than 50 characters")
            return
        }
        
        self.authenticateUser(username: username, password: password)
    }
    
    @objc private func registerButtonTapped() {
        if let url = URL(string: "\(Remote.host)/register") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func authenticateUser(username: String, password: String) {
        guard let url = URL(string: "\(Remote.host)/auth/token") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "grant_type=password&username=\(username)&password=\(password)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        request.httpBody = body?.data(using: .utf8)
        
        NSCursor.pointingHand.push()
        self.loginButton.isEnabled = false
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                NSCursor.pop()
                self?.loginButton.isEnabled = true
                
                if let error = error {
                    self?.showError(error.localizedDescription)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self?.showError("Invalid server response")
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    guard let data = data, let tokenResponse = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
                        self?.showError("Invalid response format")
                        return
                    }
                    
                    NotificationCenter.default.post(name: .remoteLoginSuccess, object: nil, userInfo: [
                        "access_token": tokenResponse.access_token,
                        "refresh_token": tokenResponse.refresh_token
                    ])
                    
                    self?.errorLabel.isHidden = true
                    self?.window?.close()
                } else {
                    self?.showError("Invalid username or password")
                }
            }
        }.resume()
    }
    
    private func showError(_ message: String) {
        self.errorLabel.stringValue = message
    }
    
    @objc private func close() {
        self.window?.close()
    }
}
