//
//  CustomStyles.swift
//  Waffl
//
//  Created by Nikhil Polepalli on 7/14/25.
//

import SwiftUI

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
            .font(.system(size: 16))
    }
}
