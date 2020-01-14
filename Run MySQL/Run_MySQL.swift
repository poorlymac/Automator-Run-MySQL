//
//  Run_MySQL.swift
//  Run MySQL
//
//  Created by Paul Schaap on 13/1/20.
//	Copyright © 2020 Paul Schaap. All rights reserved.
//
import Foundation
import Automator
import AppKit
import os.log

class Run_MySQL: AMBundleAction {

	@IBOutlet weak var textInputField: NSTextField!
    @IBOutlet weak var clientVersion: NSTextField!
    @IBOutlet weak var rowCounter: NSTextField!
    @IBOutlet weak var rowLimit: NSTextField!
    @IBOutlet weak var outputFormat: NSPopUpButton!
    @IBOutlet weak var headersCheckbox: NSButton!

    override func run(withInput input: Any?) throws -> Any {
    	// NOTE: In os_log() non-static values are marked <private>, so generated values must be explicitly marked public.
        let arrayOfValueable = input as! [String]
        os_log("The value of input is: %{public}@", arrayOfValueable[0])
        let SQL = arrayOfValueable[0]
        
        // ACTION PROPERTIES
        // Action properties are default properties of the action.
        
        // property with string value
        let actionName: String = name
        os_log("The value of action’s “name” property is: %{public}@", actionName)

        // property with boolean value
        let inputSetting: Bool  =  ignoresInput
        os_log("The value of action’s “ignoresInput” property is: %{public}@", inputSetting.description)
        
        // get the paramters dictionary
        guard let params = parameters else {
            throw NSError(domain:"Cannot unwrap parameters", code:-1, userInfo:nil)
        }

        // get the individual parameters from paramters dictionary
        guard let rowLimit: Int = params.object(forKey: "rowLimit") as? Int else {
            throw NSError(domain:"Cannot get rowLimit", code:-1, userInfo:nil)
        }
        guard let headers: Bool = params.object(forKey: "headers") as? Bool else {
            throw NSError(domain:"Cannot get headers setting", code:-1, userInfo:nil)
        }
        guard let connectionURL: String = params.object(forKey: "connectionURL") as? String else {
            throw NSError(domain:"Cannot get connectionURL", code:-1, userInfo:nil)
        }
        // NOTE: I am doing outputFormatas an IBOutlet, it may need to be a param like the above

        // Connect to database
        let conn = mysql_init(nil)
        if (conn == nil) {
            throw NSError(domain:"Could not initialise database connection", code:-1, userInfo:nil)
        }
        let url = URL(string: connectionURL)
        if(mysql_real_connect(
                conn,
                url?.host,
                url?.user ?? "root",
                url?.password ?? "root",
                url?.path.components(separatedBy: "/")[1],
                UInt32(url?.port ?? 3306),
                nil,
                0
            ) == nil) {
            throw NSError(domain:"Could not create database connection", code:0, userInfo:nil)
        }

        // Run query
        var csv = ""
        var hdr = [Int: String]()
        var dat = [String: String]()
        var dic = Array([])
        

        let queryResult = mysql_query(conn, SQL)
        if (queryResult != 0) {
            os_log("Error Running ", SQL)
            mysql_close(conn)
            throw NSError(domain:"Error (" + String(queryResult) + ") running: " + SQL, code:-1, userInfo:nil)
        } else {
            var x = 0;
            let result = mysql_store_result(conn);
            if (result != nil) {
                let fieldCount:Int = Int(mysql_num_fields(result))

                // Setup headers
                var headertext = ""
                for field in 0...(fieldCount - 1) {
                    let columnPtr = mysql_fetch_field_direct(result, UInt32(field))
                    let f: MYSQL_FIELD = columnPtr!.pointee
                    hdr[field] = String(validatingUTF8: f.name) ?? ""
                    let colName = "\"" + (String(validatingUTF8: f.name) ?? "").replacingOccurrences(of: "\"", with: "\"\"") + "\""
                    if (field == fieldCount - 1) {
                        headertext += "\(colName)\r\n"
                    } else {
                        headertext += "\(colName),"
                    }
                }
                if (headers && outputFormat.titleOfSelectedItem == "CSV") {
                    csv += headertext
                }
                
                // Get counts
                let rowCount = Int(mysql_num_rows(result))
                let numberFormatter = NumberFormatter()
                numberFormatter.numberStyle = .decimal
                let rowCountString = numberFormatter.string(from: NSNumber(value: rowCount))!
                rowCounter.stringValue = String(format: "Count: %@", arguments: [rowCountString])
                
                // Setup progress
                self.progressValue = 0
                let maxCount = rowCount
                let incrementFactor = Double(1) / Double(maxCount)
                
                var row = mysql_fetch_row(result)
                while row != nil {
                    x += 1
                    var col = ""
                    for field in 0...(fieldCount - 1) {
                        if let tabPtr = row![field] {
                            col = String(validatingUTF8: tabPtr) ?? ""
                        } else {
                            col = ""
                        }
                        if (outputFormat.titleOfSelectedItem == "CSV") {
                            if (col.contains("\"") || col.contains(",") || col.contains("\r") || col.contains("\n")) {
                                col = "\"" + col.replacingOccurrences(of: "\"", with: "\"\"") + "\""
                            }
                            if (field == fieldCount - 1) {
                                csv += "\(col)\r\n"
                            } else {
                                csv += "\(col),"
                            }
                        } else {
                            dat[String(hdr[field]!)] = col
                        }
                    }
                    if (outputFormat.titleOfSelectedItem == "CSV") {
                        // Nothing to be done
                    } else {
                        dic.append(dat)
                    }
                    
                    // Update progress
                    self.progressValue = CGFloat(Double(x) * incrementFactor)
                    
                    // Break out if limit hit
                    if ( rowLimit > 0 && x >= rowLimit) {
                        let rowCountString = numberFormatter.string(from: NSNumber(value: rowLimit))!
                        rowCounter.stringValue = String(format: rowCounter.stringValue + " (%@)", arguments: [rowCountString])
                        break
                    }
                    row = mysql_fetch_row(result)
                }
                mysql_free_result(result)
            }
        }
        os_log("Closing Connection ")
        mysql_close(conn)
        
        // LOCALIZED STRINGS
        // use getLocalizedStringForKey("KEY") to retrieve matched string in Localizable.strings file
        // let localString: String = getLocalizedStringForKey(key: "EXAMPLE_KEY")
        // os_log("Localized string: %{public}@", localString)
        
        // Return in requested format
        if (outputFormat.titleOfSelectedItem == "CSV") {
            return csv
        } else {
            return dic
        }
    }

    // Invoked when the action is first added to a workflow, allowing it to initialize its user interface.
	override func opened(){
        let clientInfo:String = String(cString: mysql_get_client_info())
        clientVersion.stringValue = "Client: \(clientInfo)"
    }
    
    // Requests the action to update its user interface from its stored parameters, which have changed.
    override func parametersUpdated(){
    	print("parametersUpdated")
    }
    
    // Requests the action to update its stored set of parameters from the settings in the action’s user interface.
    override func updateParameters(){
    	print("updateParameters")
    }
    
    // Invoked by Automator when the receiving action is removed from a workflow, allowing it to perform cleanup operations.
    override func closed(){
    	print("closed")
    }
    
    // Invoked when the window of the Automator workflow to which the receiver belongs becomes the main window. This allows the action to synchronize its information with settings in another application.
    override func activated(){
        print("activated")
        
    }
    
	// Resets the action to its initial state.
    override func reset(){
        print("reset")
    }
        
    // Returns a localized version of the string designated by the specified key and residing in the specified table.
    // If tableName is nil or is an empty string, the method attempts to use the table in Localizable.strings.
    func getLocalizedStringForKey(key: String) -> String {
    	// use “bundle” property of AMBundleAction class to identify this action’s bundle
        let actionBundle: Bundle  =  bundle
        return NSLocalizedString(key, tableName: nil, bundle: actionBundle, value: "", comment: "")
    }
    
    // interface action code triggered by a button added to the action view
    @IBAction func actionButton(sender: AnyObject) {
        if (outputFormat.titleOfSelectedItem == "CSV") {
            headersCheckbox.isEnabled = true
        } else {
            headersCheckbox.isEnabled = false
        }
    }
    
    // basic informational dialog
	func basicAlertDialog(alertTitle: String, alertMessage: String) -> Bool {
		NSSound.beep()
		let alert = NSAlert()
		alert.messageText = alertTitle
		alert.informativeText = alertMessage
		alert.alertStyle = .informational
		alert.addButton(withTitle: "OK")
		alert.runModal()
		return true
	}
    
    // basic dialog with choice
	func basicTwoOptionDialogWithCancel(alertTitle: String, alertMessage: String, firstButtonTitle: String, secondButtonTitle: String) -> String {
		NSSound.beep()
		let alert = NSAlert()
		alert.messageText = alertTitle
		alert.informativeText = alertMessage
		alert.alertStyle = .informational
		alert.addButton(withTitle: firstButtonTitle)
		alert.addButton(withTitle: secondButtonTitle)
		alert.addButton(withTitle: "Cancel")
		let dialogResult =  alert.runModal()
		if dialogResult == NSApplication.ModalResponse.alertFirstButtonReturn {
			return firstButtonTitle
		} else if dialogResult == NSApplication.ModalResponse.alertSecondButtonReturn {
			return secondButtonTitle
		} else {
			return "Cancel"
		}
	}
    
    // basic yes or no alert dialog
	func basicConfirmationDialog(alertTitle: String, alertMessage: String) -> Bool {
		NSSound.beep()
		let alert: NSAlert = NSAlert()
		alert.messageText = alertTitle
		alert.informativeText = alertMessage
		alert.alertStyle = .informational // critical, warning, informational
		alert.addButton(withTitle:"OK")
		alert.addButton(withTitle:"Cancel")
		let dialogResult = alert.runModal()
		if dialogResult == NSApplication.ModalResponse.alertFirstButtonReturn {
			return true
		}
		return false
	}
}
