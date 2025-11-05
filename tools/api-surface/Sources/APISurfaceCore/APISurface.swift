/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

import Foundation
import SourceKittenFramework

public struct APISurfaceError: Error, CustomStringConvertible {
    public let description: String
}

public struct APISurface {
    private let module: Module
    private let language: Language
    private let generator = Generator()
    private let printer = Printer()

    // MARK: - Initialization

    /// Creates API surface for an SPM library.
    /// - Parameters:
    ///   - libraryName: the name of Swift library for generating API surface.
    ///   - path: the path to a folder containing `Package.swift`.
    ///   - language: the language of the API surface.
    public init(spmLibraryName libraryName: String, inPath path: String, language: Language) throws {
        // Ensure swift build has been run first
        let buildProcess = Process()
        buildProcess.launchPath = "/usr/bin/swift"
        buildProcess.arguments = ["build"]
        buildProcess.currentDirectoryPath = path
        buildProcess.standardOutput = FileHandle.nullDevice
        buildProcess.standardError = FileHandle.nullDevice
        buildProcess.launch()
        buildProcess.waitUntilExit()
        
        if buildProcess.terminationStatus != 0 {
            throw APISurfaceError(description: "Failed to build Swift package. Run 'swift build' manually to check for errors.")
        }
        
        // Create module from SPM build record
        guard let module = Module(spmName: libraryName, inPath: path) else {
            throw APISurfaceError(description: "Failed to generate module interface with `SourceKittenFramework`.")
        }
        
        self.module = module
        self.language = language
    }

    // MARK: - Output

    public func print() throws -> String {
        let items = try generator.generateSurfaceItems(for: module, language: language)
        return printer.print(items: items)
    }
}
