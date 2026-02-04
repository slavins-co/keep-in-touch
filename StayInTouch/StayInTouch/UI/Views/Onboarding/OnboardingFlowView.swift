//
//  OnboardingFlowView.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import SwiftUI

struct OnboardingFlowView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        switch viewModel.step {
        case .welcome:
            WelcomeView(viewModel: viewModel)
        case .contactsPermission:
            ContactsPermissionView(viewModel: viewModel)
        case .contactsRequired:
            ContactsRequiredView(viewModel: viewModel)
        case .contactPicker:
            ContactPickerView(viewModel: viewModel)
        case .groupAssignment:
            GroupAssignmentView(viewModel: viewModel)
        case .notificationsPermission:
            NotificationsPermissionView(viewModel: viewModel)
        case .notificationsSkipped:
            NotificationsSkippedView(viewModel: viewModel)
        }
    }
}

#Preview {
    OnboardingFlowView(viewModel: OnboardingViewModel())
}
