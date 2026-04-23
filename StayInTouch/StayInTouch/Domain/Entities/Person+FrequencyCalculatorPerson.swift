//
//  Person+FrequencyCalculatorPerson.swift
//  KeepInTouch
//
//  Passthrough conformance — every required property already exists
//  on `Person`. Lets `FrequencyCalculator` consume `Person` directly
//  while the widget uses its own lightweight adapter struct.
//

import Foundation

extension Person: FrequencyCalculatorPerson {}
