import SwiftUI
import Supabase

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                PeakColors.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    // Logo or Header
                    Text(isSignUp ? "Создать аккаунт" : "Вход в Peak")
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .foregroundStyle(PeakColors.textPrimary)
                        .padding(.bottom, 20)

                    // Error/Success Message
                    if let error = errorMessage {
                        Text(error)
                            .font(PeakTypography.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    } else if let success = successMessage {
                        Text(success)
                            .font(PeakTypography.caption)
                            .foregroundStyle(.green)
                            .multilineTextAlignment(.center)
                    }

                    // Inputs
                    VStack(spacing: 16) {
                        if isSignUp {
                            authTextField(title: "Имя пользователя", text: $username)
                        }
                        authTextField(title: "Email", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                        
                        SecureField("Пароль", text: $password)
                            .padding()
                            .background(Color(white: 0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(PeakColors.textPrimary)
                    }

                    // Primary Button
                    Button {
                        Task { await authenticate() }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .tint(PeakColors.black)
                        } else {
                            Text(isSignUp ? "Зарегистрироваться" : "Войти")
                                .font(PeakTypography.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(PeakColors.textPrimary)
                    .foregroundStyle(PeakColors.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(isLoading || email.isEmpty || password.isEmpty || (isSignUp && username.isEmpty))

                    // Toggle Mode
                    Button {
                        withAnimation {
                            isSignUp.toggle()
                            errorMessage = nil
                            successMessage = nil
                        }
                    } label: {
                        Text(isSignUp ? "Уже есть аккаунт? Войти" : "Нет аккаунта? Создать")
                            .font(PeakTypography.callout)
                            .foregroundStyle(PeakColors.textSecondary)
                    }
                    .padding(.top, 10)
                }
                .padding(30)
            }
        }
    }

    private func authTextField(title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .padding()
            .background(Color(white: 0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(PeakColors.textPrimary)
    }

    private func authenticate() async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        do {
            if isSignUp {
                try await AuthenticationService.shared.signUp(email: email, password: password, username: username)
                successMessage = "Успешно! Проверьте вашу почту для подтверждения аккаунта."
            } else {
                try await AuthenticationService.shared.signIn(email: email, password: password)
            }
        } catch {
            let errString = error.localizedDescription
            if errString.contains("Email not confirmed") {
                errorMessage = "Почта не подтверждена. Проверьте входящие письма."
            } else if errString.contains("Invalid login credentials") {
                errorMessage = "Неверный email или пароль."
            } else {
                errorMessage = errString
            }
        }
        isLoading = false
    }
}
