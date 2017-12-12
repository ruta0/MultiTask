//
//  PendingDetailViewController.swift
//  MultiTask
//
//  Created by rightmeow on 8/9/17.
//  Copyright © 2017 Duckensburg. All rights reserved.
//

import UIKit
import AVFoundation
import RealmSwift

class ItemsViewController: BaseViewController, UITableViewDelegate, UITableViewDataSource, UIViewControllerPreviewingDelegate, PersistentContainerDelegate, ItemEditorViewControllerDelegate, SoundEffectDelegate, TaskHeaderViewDelegate, TaskEditorViewControllerDelegate {

    // MARK: - API

    var realmManager: RealmManager?
    var soundEffectManager: SoundEffectManager?
    var selectedTask: Task?
    var items: [Results<Item>]?
    var notificationToken: NotificationToken?

    var itemEditorViewController: ItemEditorViewController?
    var searchController: UISearchController!
    static let storyboard_id = String(describing: ItemsViewController.self)

    @IBOutlet weak var addButton: UIBarButtonItem!
    @IBOutlet weak var taskHeaderView: TaskHeaderView!
    @IBOutlet weak var tashHeaderViewHeightLayoutConstraint: NSLayoutConstraint!
    @IBOutlet weak var tableView: UITableView!

    // MARK: - ItemEditorViewControllerDelegate

    func itemEditorViewController(_ viewController: ItemEditorViewController, didAddItem item: Item) {
        if let navController = self.navigationController as? BaseNavigationController {
            navController.popViewController(animated: true)
            // update the parent task's updated_at
            guard let task = self.selectedTask else { return }
            self.realmManager?.updateObject(object: task, keyedValues: [Task.updatedAtKeyPath : NSDate()])
            self.tableView.backgroundView?.isHidden = true
        }
    }

    func itemEditorViewController(_ viewController: ItemEditorViewController, didUpdateItem item: Item) {
        if let navController = self.navigationController as? BaseNavigationController {
            navController.popViewController(animated: true)
        }
    }

    // MARK: - UISearchControllerDelegate

    private func setupSearchController() {
        guard let searchResultsViewController = self.storyboard?.instantiateViewController(withIdentifier: SearchResultsViewController.storyboard_id) as? SearchResultsViewController else { return }
        searchResultsViewController.itemsViewController = self
        self.searchController = UISearchController(searchResultsController: searchResultsViewController)
        searchResultsViewController.selectedTask = self.selectedTask
        self.searchController.searchResultsUpdater = searchResultsViewController
        self.searchController.searchBar.barStyle = .black
        self.searchController.searchBar.tintColor = Color.mandarinOrange
        self.searchController.dimsBackgroundDuringPresentation = true
        self.searchController.searchBar.keyboardAppearance = UIKeyboardAppearance.dark
        self.definesPresentationContext = true
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = true
    }

    // MARK: - SoundEffectDelegate

    private func setupSoundEffectDelegate() {
        self.soundEffectManager = SoundEffectManager()
        self.soundEffectManager!.delegate = self
    }

    func soundEffect(_ manager: SoundEffectManager, didPlaySoundEffect soundEffect: SoundEffect, player: AVAudioPlayer) {
        // implement this if needed
    }

    func soundEffect(_ manager: SoundEffectManager, didErr error: Error) {
        if let navigationController = self.navigationController as? BaseNavigationController {
            navigationController.scheduleNavigationPrompt(with: error.localizedDescription, duration: 5)
        }
    }

    // MARK: - PersistentContainerDelegate

    private func setupPersistentContainerDelegate() {
        realmManager = RealmManager()
        realmManager!.delegate = self
    }

    private func setupItemsForTableViewWithParentTask() {
        guard let unwrappedItems = self.selectedTask?.items.sorted(byKeyPath: Item.createdAtKeyPath, ascending: false).sorted(byKeyPath: Item.isCompletedKeyPath, ascending: true) else { return }
        self.items = [Results<Item>]()
        self.items!.append(unwrappedItems)
        self.setupRealmNotificationsForTableView()
        self.tableView.backgroundView?.isHidden = unwrappedItems.isEmpty ? false : true
    }

    private func setupRealmNotificationsForTableView() {
        notificationToken = self.items!.first?.observe({ [weak self] (changes) in
            guard let tableView = self?.tableView else { return }
            switch changes {
            case .initial:
                tableView.reloadData()
            case .update(_, deletions: let deletions, insertions: let insertions, modifications: let modifications):
                tableView.applyChanges(deletions: deletions, insertions: insertions, updates: modifications)
            case .error(let err):
                print(trace(file: #file, function: #function, line: #line))
                print(err.localizedDescription)
            }
        })
    }

    func persistentContainer(_ manager: RealmManager, didErr error: Error) {
        if let navigationController = self.navigationController as? BaseNavigationController {
            navigationController.scheduleNavigationPrompt(with: error.localizedDescription, duration: 5)
        }
    }

    func persistentContainer(_ manager: RealmManager, didFetchItems items: Results<Item>?) {
        if let fetchedItems = items, !fetchedItems.isEmpty {
            self.tableView.backgroundView?.isHidden = true
        } else {
            self.tableView.backgroundView?.isHidden = true
        }
    }

    func persistentContainer(_ manager: RealmManager, didDeleteItems items: [Item]?) {
        // REMARK: delete an item from items may cause the parentTask to toggle its completion state to either completed or pending. Check to see if the parent task has all items completed, if so, mark parent task completed and set the updated_at and completed_at to today's date
        guard let parentTask = self.selectedTask else { return }
        self.realmManager?.updateObject(object: parentTask, keyedValues: [Task.isCompletedKeyPath : parentTask.shouldComplete(), Task.updatedAtKeyPath : NSDate()])


        if parentTask.shouldComplete() == true {
            self.realmManager?.updateObject(object: parentTask, keyedValues: [Task.isCompletedKeyPath : true, Task.updatedAtKeyPath : NSDate()])
            self.postNotificationForTaskCompletion(completedTask: parentTask)
            // play sound effect
            self.soundEffectManager?.play(soundEffect: SoundEffect.Coin)
        } else if parentTask.shouldComplete() == false {
            self.realmManager?.updateObject(object: parentTask, keyedValues: [Task.isCompletedKeyPath : false, Task.updatedAtKeyPath : NSDate()])
            self.postNotificationForTaskPending(pendingTask: parentTask)
        } else {
            // parentTask.shouldComplete() == nil
            // having updated an item doesn't cause the parentTask to change its completion state
        }
    }

    func persistentContainer(_ manager: RealmManager, didUpdateObject object: Object) {
        // REMARK: updating an item from items may cause the parentTask to toggle its completion state to either completed or pending. Check to see if the parent task has all items completed, if so, mark parent task completed and set the updated_at and completed_at to today's date
        if let updatedTask = object as? Task {
            // update the header
            self.taskHeaderView.selectedTask = updatedTask
        } else if let _ = object as? Item {
            guard let parentTask = self.selectedTask else { return }
            self.realmManager?.updateObject(object: parentTask, keyedValues: [Task.isCompletedKeyPath : parentTask.shouldComplete(), Task.updatedAtKeyPath : NSDate()])
            if parentTask.shouldComplete() == true {
                self.postNotificationForTaskCompletion(completedTask: parentTask) // notify MainCompletedTasksCell
                self.soundEffectManager?.play(soundEffect: SoundEffect.Coin)
            } else {
                self.postNotificationForTaskPending(pendingTask: parentTask) // notify MainPendingTasksCell
            }
        } else {
            // don't know what object it is, ignore, for now...
        }
    }

    // MARK: - TaskHeaderViewDelegate

    private func setupTaskHeaderViewDelegate() {
        self.taskHeaderView.delegate = self
    }

    private func setupTaskHeaderView() {
        self.taskHeaderView.selectedTask = self.selectedTask
        // calculate the total height for the headerView
        let viewHeight: CGFloat = 16 + 16 + (0) + 8 + 15 + 15 + 15 + 16 + 16 // containerViewTopMargin, titleLabelTopMargin, titleLabelHeight, titleLabelBottomMargin, subtitleLabelHeight, dateLabelHeight, statsLabelHeight, statsLabelBottomMargin, containerViewBottomMargin
        let titleWidth: CGFloat = self.view.frame.width - 16 - 16 - 16 - 16 - 16
        if let task = self.selectedTask {
            var estimatedHeightForTitle = task.title.heightForText(systemFont: 15, width: titleWidth)
            // FIXME: Must override the estimatedHeight! because when estimatedHeight is too big, the whole screen will be covered by the header and currently there is no way to scroll to see the content hidden below, for now.
            self.taskHeaderView.titleTextView.isScrollEnabled = false
            if estimatedHeightForTitle > self.view.frame.height / 7 {
                estimatedHeightForTitle = self.view.frame.height / 7
                self.taskHeaderView.titleTextView.isScrollEnabled = true
            }
            self.tashHeaderViewHeightLayoutConstraint.constant = viewHeight + estimatedHeightForTitle
            UIView.animate(withDuration: 0.15, animations: {
                self.view.layoutIfNeeded()
            }, completion: nil)
        }
    }

    func taskHeaderView(_ view: TaskHeaderView, didTapEdit button: UIButton) {
        // push to task editor
        self.performSegue(withIdentifier: Segue.EditButtonToTaskEditorViewController, sender: self)
    }

    // MARK: - TaskEditorViewControllerDelegate

    func taskEditorViewController(_ viewController: TaskEditorViewController, didAddTask task: Task) {
        // ignore
    }

    func taskEditorViewController(_ viewController: TaskEditorViewController, didUpdateTask task: Task) {
        if let navigationViewController = self.navigationController as? BaseNavigationController {
            navigationViewController.popToViewController(self, animated: true)
            // update taskHeaderView's data
            self.taskHeaderView.selectedTask = task
        }
    }

    // MARK: - Notifications

    func postNotificationForTaskCompletion(completedTask: Task) {
        let notification = Notification(name: Notification.Name(rawValue: NotificationKey.TaskCompletion), object: nil, userInfo: [NotificationKey.TaskCompletion : completedTask])
        NotificationCenter.default.post(notification)
    }

    func postNotificationForTaskPending(pendingTask: Task) {
        let notification = Notification(name: Notification.Name(rawValue: NotificationKey.TaskPending), object: nil, userInfo: [NotificationKey.TaskPending : pendingTask])
        NotificationCenter.default.post(notification)
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupNavigationBar()
        self.setupTableView()
        self.setupSearchController()
        self.setupSoundEffectDelegate()
        self.setupViewControllerPreviewingDelegate()
        self.setupPersistentContainerDelegate()
        self.setupItemsForTableViewWithParentTask()
        self.setupTaskHeaderView()
        self.setupTaskHeaderViewDelegate()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Segue.ItemsViewControllerToItemEditorViewController {
            itemEditorViewController = segue.destination as? ItemEditorViewController
            itemEditorViewController?.hidesBottomBarWhenPushed = true
            itemEditorViewController?.delegate = self
            itemEditorViewController?.parentTask = self.selectedTask
        } else if segue.identifier == Segue.EditButtonToTaskEditorViewController {
            if let taskEditorViewController = segue.destination as? TaskEditorViewController {
                taskEditorViewController.hidesBottomBarWhenPushed = true
                taskEditorViewController.selectedTask = self.selectedTask
                taskEditorViewController.delegate = self
            }
        }
    }

    // MARK: - UIViewControllerPreviewingDelegate

    private func setupViewControllerPreviewingDelegate() {
        self.registerForPreviewing(with: self, sourceView: self.tableView)
    }

    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        if let navController = self.navigationController as? BaseNavigationController {
            viewControllerToCommit.hidesBottomBarWhenPushed = true
            navController.pushViewController(viewControllerToCommit, animated: true)
        }
    }

    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        guard let indexPath = self.tableView.indexPathForRow(at: location) else { return nil }
        let itemEditorViewController = storyboard?.instantiateViewController(withIdentifier: ItemEditorViewController.storyboard_id) as? ItemEditorViewController
        itemEditorViewController?.delegate = self
        itemEditorViewController?.parentTask = self.selectedTask
        itemEditorViewController?.selectedItem = items?[indexPath.section][indexPath.row]
        // setting the peeking cell's animation
        if let selectedCell = self.tableView.cellForRow(at: indexPath) as? ItemCell {
            previewingContext.sourceRect = selectedCell.frame
        }
        return itemEditorViewController
    }

    // MARK: - NavigationBar

    private func setupNavigationBar() {
        self.navigationItem.title?.removeAll()
    }

    @IBAction func handleAdd(_ sender: UIBarButtonItem) {
        self.performSegue(withIdentifier: Segue.ItemsViewControllerToItemEditorViewController, sender: self)
    }

    // MARK: - UITableView

    private func setupTableView() {
        self.tableView.backgroundColor = Color.inkBlack
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.register(UINib(nibName: ItemCell.nibName, bundle: nil), forCellReuseIdentifier: ItemCell.cell_id)
        self.tableView.backgroundView = self.initPlaceholderBackgroundView(type: PlaceholderType.items)
    }

    // MARK: - UITableViewDelegate

    func isItemCompleted(at indexPath: IndexPath) -> Bool? {
        if let is_completed = items?[indexPath.section][indexPath.row].is_completed {
            return is_completed
        } else {
            return nil
        }
    }

    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        // user marks item for pending
        let pendingAction = UIContextualAction(style: UIContextualAction.Style.normal, title: nil) { (action, view, is_success) in
            // REMARK: perform pending action may cause a completedTask to be transferred to PendingTasksViewController, however when pendingTasks in PendingTasksViewController is nil. It is not tracked by RealmNotification by default, so the UI may not be able to perform its update to show the task that has just been transferred.
            // to fix this, perform a manual fetch on PendingTasksViewController to get everything kickstarted.
            if let itemToBePending = self.items?[indexPath.section][indexPath.row] {
                self.realmManager?.updateObject(object: itemToBePending, keyedValues: [Item.isCompletedKeyPath : false, Item.updatedAtKeyPath : NSDate()])
            } else {
                print(trace(file: #file, function: #function, line: #line))
            }
            is_success(true)
        }
        pendingAction.image = #imageLiteral(resourceName: "Code") // <<-- watch out for image literal
        pendingAction.backgroundColor = Color.mandarinOrange
        // user marks item for completion
        let doneAction = UIContextualAction(style: UIContextualAction.Style.normal, title: nil) { (action, view, is_success) in
            // REMARK: when a item is marked completed, it may cause the parentTask to change its completion state to is_completed == true. However, if completedViewController has no completedTasks to keep track of by realmNotification, it will not update on its own! The same goes with pendingAction! To fix this issue, perform a manual fetch on CompletedTasksViewController to get everything kickstarted.
            if let itemToBeCompleted = self.items?[indexPath.section][indexPath.row] {
                self.realmManager?.updateObject(object: itemToBeCompleted, keyedValues: [Item.isCompletedKeyPath : true, Item.updatedAtKeyPath : NSDate()])
            } else {
                print(trace(file: #file, function: #function, line: #line))
            }
            is_success(true)
        }
        doneAction.image = #imageLiteral(resourceName: "Tick") // <<-- watch out for image literal. It's almost invisible.
        doneAction.backgroundColor = Color.seaweedGreen
        // if this cell has been completed, show pendingAction, if not, show doneAction
        if let is_completed = self.isItemCompleted(at: indexPath) {
            if is_completed {
                let swipeActionConfigurations = UISwipeActionsConfiguration(actions: [pendingAction])
                swipeActionConfigurations.performsFirstActionWithFullSwipe = true
                return swipeActionConfigurations
            } else {
                let swipeActionConfigurations = UISwipeActionsConfiguration(actions: [doneAction])
                swipeActionConfigurations.performsFirstActionWithFullSwipe = true
                return swipeActionConfigurations
            }
        } else {
            return nil
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: UIContextualAction.Style.destructive, title: nil) { (action, view, is_success) in
            // REMARK: perform a delete action may cause its parent Task to changed its completion state to either complete or incomplete.
            // REMARK: If task should become complete, but CompletedTasksViewController's completedTasks == nil, then CompletedTasksViewController will not be able to update its UI to correspond to new changes because RealmNotification does not track nil values. To fix this issue, first check if completedTasks == nil, if so perform a manual fetch. If completedTasks != nil, that mean RealmNotification has already place a the array on its run loop. Then no additional work needed to be done there, because it is already working properly.
            // REMARK: if task should become incomplete, but PendingTasksViewController's pendingTasks == nil, then PendingTasksViewController will not be able to update its UI to correspond to new changes because RealmNotification does not track nil values. To fix this issue, first check if pendingTasks == nil, if so perform a manual fetch. If pendingTasks != nil, that mean RealmNotification has already place a the array on its run loop. Then no additional work needed to be done there, because it is already working properly.
            if let itemToBeDeleted = self.items?[indexPath.section][indexPath.row] {
                self.realmManager?.deleteItems(items: [itemToBeDeleted])
            } else {
                print(trace(file: #file, function: #function, line: #line))
            }
            is_success(true)
        }
        deleteAction.image = #imageLiteral(resourceName: "Trash") // <<-- watch out for image literal
        deleteAction.backgroundColor = Color.roseScarlet
        let swipeActionConfigurations = UISwipeActionsConfiguration(actions: [deleteAction])
        swipeActionConfigurations.performsFirstActionWithFullSwipe = false
        return swipeActionConfigurations
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 56
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let itemCell = self.tableView.dequeueReusableCell(withIdentifier: ItemCell.cell_id, for: indexPath) as? ItemCell {
            let item = items?[indexPath.section][indexPath.row]
            itemCell.item = item
            return itemCell
        } else {
            return BaseTableViewCell()
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items?[section].count ?? 0
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return items?.count ?? 0
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

}
