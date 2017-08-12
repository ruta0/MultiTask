//
//  Task.swift
//  MultiTask
//
//  Created by rightmeow on 8/9/17.
//  Copyright © 2017 Duckensburg. All rights reserved.
//

import Foundation
import RealmSwift

final class Task: Object {

    dynamic var id: String = ""
    dynamic var name = ""
    var items = List<Item>()
    dynamic var is_completed = false
    dynamic var created_at = NSDate()
    dynamic var updated_at = NSDate()

    static let pendingPredicate = NSPredicate(format: "is_completed == %@", NSNumber(booleanLiteral: false))
    static let completedPredicate = NSPredicate(format: "is_completed == %@", NSNumber(booleanLiteral: true))

    override static func primaryKey() -> String? {
        return "id"
    }

    convenience init(id: String, name: String, items: List<Item>, is_completed: Bool, created_at: NSDate, updated_at: NSDate) {
        self.init()
        self.id = id
        self.name = name
        self.items = items
        self.is_completed = is_completed
        self.created_at = created_at
        self.updated_at = updated_at
    }

}
