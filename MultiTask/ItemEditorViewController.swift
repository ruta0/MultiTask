//
//  ItemEditorView.swift
//  MultiTask
//
//  Created by rightmeow on 11/12/17.
//  Copyright © 2017 Duckensburg. All rights reserved.
//

import UIKit
import Amplitude
import RealmSwift

protocol ItemEditorViewControllerDelegate: NSObjectProtocol {
    func itemEditorViewController(_ viewController: ItemEditorViewController, didUpdateItem item: Item)
    func itemEditorViewController(_ viewController: ItemEditorViewController, didAddItem item: Item)
}

class ItemEditorViewController: BaseViewController {

//    var realmManager: RealmManager?
    var parentTask: Task?
    var selectedItem: Item?
    weak var delegate: ItemEditorViewControllerDelegate?
    static let storyboard_id = String(describing: ItemEditorViewController.self)
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var contentContainerView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var titleTextView: UITextView!
    @IBOutlet weak var saveButton: UIButton!

    @IBAction func handleSave(_ sender: UIButton) {
        self.titleTextView.resignFirstResponder()
        // if selectedItem is nil, that means this MVC is segued from the AddButton, else it is initiated with peek and pop
        if self.selectedItem != nil {
            self.selectedItem!.title = self.titleTextView.text
            self.selectedItem!.save()
        } else {
            let newItem = self.create()
            self.append(newItem: newItem)
        }
    }
    
    // update an existing item
    func update(item: Item, keyedValues: [String : Any]) {
        // FIXME: if I update this item idenpendently, I lose the sight of its parent task so that I won't be able to check for parent's completion state.
        do {
            try defaultRealm.write {
                item.setValuesForKeys(keyedValues)
                defaultRealm.add(item, update: true)
            }
        } catch let err {
            print(err.localizedDescription)
            Amplitude.instance().logEvent(LogEventType.relamError)
        }
    }
    
    // append a item to the items list array
    func append(newItem: Item) {
        if newItem.isValid() {
            do {
                try defaultRealm.write {
                    self.parentTask!.is_completed = false
                    self.parentTask!.items.append(newItem)
                }
            } catch let err {
                print(err.localizedDescription)
                Amplitude.instance().logEvent(LogEventType.relamError)
            }
        } else {
            print("invalid format for item")
        }
    }
    
    // create a new item
    func create() -> Item {
        let item = Item(title: titleTextView.text)
        return item
    }

    private func setupView() {
        self.view.backgroundColor = Color.inkBlack
        self.scrollView.backgroundColor = Color.clear
        self.scrollView.delaysContentTouches = false
        self.containerView.backgroundColor = Color.clear
        self.contentContainerView.backgroundColor = Color.inkBlack
        self.titleLabel.backgroundColor = Color.clear
        self.titleLabel.textColor = Color.white
        self.titleLabel.text = self.selectedItem == nil ? "Add a new item" : "Edit an item"
        self.subtitleLabel.backgroundColor = Color.clear
        self.subtitleLabel.textColor = Color.lightGray
        self.titleTextView.backgroundColor = Color.midNightBlack
        self.titleTextView.textColor = Color.white
        self.titleTextView.layer.cornerRadius = 8
        self.titleTextView.clipsToBounds = true
        self.titleTextView.delegate = self
        self.titleTextView.tintColor = Color.mandarinOrange
        self.titleTextView.text = self.selectedItem == nil ? "" : selectedItem!.title
        self.saveButton.setTitle("Save", for: UIControlState.normal)
        self.saveButton.layer.cornerRadius = 8
        self.saveButton.backgroundColor = Color.seaweedGreen
        self.saveButton.setTitleColor(Color.inkBlack, for: UIControlState.disabled)
        self.saveButton.setTitleColor(Color.white, for: UIControlState.normal)
        self.saveButton.isEnabled = false
        if self.selectedItem == nil {
            self.subtitleLabel.isHidden = true
        } else {
            self.subtitleLabel.text = "Hash. " + selectedItem!.id
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupView()
//        self.setupPersistentContainerDelegate()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.titleTextView.becomeFirstResponder()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.titleTextView.resignFirstResponder()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

}

//extension ItemEditorViewController: PersistentContainerDelegate {
//
//    private func setupPersistentContainerDelegate() {
//        realmManager = RealmManager()
//        realmManager!.delegate = self
//    }
//
//    func persistentContainer(_ manager: RealmManager, didErr error: Error) {
//        if let navigationController = self.navigationController as? BaseNavigationController {
//            navigationController.scheduleNavigationPrompt(with: error.localizedDescription, duration: 5)
//        }
//    }
//
//    func persistentContainer(_ manager: RealmManager, didUpdateObject object: Object) {
//        // called when successfully updated an existing item
//        if let item = self.selectedItem {
//            self.delegate?.itemEditorViewController(self, didUpdateItem: item)
//        } else {
//            print(trace(file: #file, function: #function, line: #line))
//            if let navController = self.navigationController as? BaseNavigationController {
//                navController.popViewController(animated: true)
//            }
//        }
//    }
//
//    func persistentContainer(_ manager: RealmManager, didAddObjects objects: [Object]) {
//        // called when successfully appened a new item to task
//        if let newItem = objects.first as? Item {
//            self.delegate?.itemEditorViewController(self, didAddItem: newItem)
//        } else {
//            print(trace(file: #file, function: #function, line: #line))
//            if let navController = self.navigationController as? BaseNavigationController {
//                navController.popViewController(animated: true)
//            }
//        }
//    }
//
//}

extension ItemEditorViewController: UITextViewDelegate {
    
    func textViewDidChange(_ textView: UITextView) {
        self.saveButton.isEnabled = textView.text.count > 2 ? true : false
    }
    
}
