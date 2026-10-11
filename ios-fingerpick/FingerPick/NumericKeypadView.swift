import SwiftUI
import UIKit

struct NumericKeypadView: View {
    @Binding var textValue: String
    var title: String? = nil
    var subtitle: String? = nil
    var allowNegative: Bool = true
    var quickPresets: [Int]? = nil
    var onValidate: (Int) -> Void
    var onCancel: (() -> Void)? = nil
    
    @State private var shakeTrigger: Bool = false
    
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .light)
    
    var currentValue: Int {
        Int(textValue) ?? 0
    }
    
    var body: some View {
        VStack(spacing: 14) {
            // Header / Display
            VStack(spacing: 4) {
                if let title = title {
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .textCase(.uppercase)
                }
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                }
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(textValue.isEmpty ? "0" : textValue)
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.08))
                )
            }
            .padding(.top, 4)
            
            // Optional Quick Presets row
            if let presets = quickPresets, !presets.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(presets, id: \.self) { preset in
                            Button {
                                hapticFeedback.impactOccurred()
                                textValue = "\(preset)"
                            } label: {
                                Text("\(preset)")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(currentValue == preset ? Color.cyan.opacity(0.6) : Color.white.opacity(0.12))
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
            
            // Keypad Grid
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    keypadButton("1")
                    keypadButton("2")
                    keypadButton("3")
                }
                
                HStack(spacing: 10) {
                    keypadButton("4")
                    keypadButton("5")
                    keypadButton("6")
                }
                
                HStack(spacing: 10) {
                    keypadButton("7")
                    keypadButton("8")
                    keypadButton("9")
                }
                
                HStack(spacing: 10) {
                    if allowNegative {
                        Button {
                            hapticFeedback.impactOccurred()
                            toggleSign()
                        } label: {
                            Text("+/−")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .foregroundStyle(.white.opacity(0.9))
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.white.opacity(0.15))
                                )
                        }
                        .frame(height: 52)
                    } else {
                        Button {
                            hapticFeedback.impactOccurred()
                            textValue = ""
                        } label: {
                            Text("C")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .foregroundStyle(.orange)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.white.opacity(0.12))
                                )
                        }
                        .frame(height: 52)
                    }
                    
                    keypadButton("0")
                    
                    Button {
                        hapticFeedback.impactOccurred()
                        deleteLast()
                    } label: {
                        Image(systemName: "delete.left.fill")
                            .font(.system(size: 19, weight: .bold))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .foregroundStyle(.white.opacity(0.85))
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.15))
                            )
                    }
                    .frame(height: 52)
                }
            }
            .padding(.horizontal, 16)
            
            // Action Buttons
            HStack(spacing: 12) {
                if let onCancel = onCancel {
                    Button(action: onCancel) {
                        Text("Annuler")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.12))
                            )
                    }
                }
                
                Button {
                    let impact = UINotificationFeedbackGenerator()
                    impact.notificationOccurred(.success)
                    let val = Int(textValue) ?? 0
                    onValidate(val)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Valider")
                    }
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.cyan)
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(Color(red: 0.08, green: 0.10, blue: 0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 26)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.5), radius: 24, y: 10)
        )
    }
    
    private func keypadButton(_ digit: String) -> some View {
        Button {
            hapticFeedback.impactOccurred()
            appendDigit(digit)
        } label: {
            Text(digit)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.10))
                )
        }
        .frame(height: 52)
    }
    
    private func appendDigit(_ digit: String) {
        if textValue == "0" {
            textValue = digit
        } else if textValue == "-0" {
            textValue = "-\(digit)"
        } else if textValue.count < 6 {
            textValue += digit
        }
    }
    
    private func deleteLast() {
        if !textValue.isEmpty {
            textValue.removeLast()
            if textValue == "-" {
                textValue = ""
            }
        }
    }
    
    private func toggleSign() {
        if textValue.hasPrefix("-") {
            textValue.removeFirst()
        } else if !textValue.isEmpty && textValue != "0" {
            textValue = "-" + textValue
        }
    }
}
