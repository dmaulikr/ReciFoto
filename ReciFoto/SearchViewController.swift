//
//  SearchViewController.swift
//  ReciFoto
//
//  Created by Colin Taylor on 1/20/17.
//  Copyright © 2017 Colin Taylor. All rights reserved.
//

import UIKit
public enum SearchMode: String {
    case trends = "trends"
    case search = "search"
}
class SearchViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UISearchBarDelegate {

    @IBOutlet weak var lblNoResult: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!
    var currentIndex = 0
    var currentMode : SearchMode = .trends
    var currentSearchKey : String = ""
    
    
    fileprivate var filteredNames: [AnyObject] = []
    
    fileprivate var names : [AnyObject] = []
    
    fileprivate var readyForPresentation = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
//        self.navigationItem.title = "Search"
        let titleButton =  UIButton(type: .custom)
        titleButton.frame = CGRect(x: 0, y: 0, width: 100, height: 40)
        titleButton.backgroundColor = UIColor.clear
        titleButton.setTitle("Search", for: .normal)
        titleButton.addTarget(self, action: #selector(self.clickOnTitleButton), for: .touchUpInside)
        self.navigationItem.titleView = titleButton
        
        self.filteredNames = self.names
        
        self.collectionView.register(SearchCollectionViewCell.self, forCellWithReuseIdentifier: "SearchCollectionViewCell.identifier")
        self.collectionView.register(TextCollectionViewCell.self, forCellWithReuseIdentifier: "TextCollectionViewCell.identifier")
        
        if let collectionViewLayout = self.collectionView.collectionViewLayout as? RSKCollectionViewRetractableFirstItemLayout {
            
            collectionViewLayout.firstItemRetractableAreaInset = UIEdgeInsets(top: 8.0, left: 0.0, bottom: 8.0, right: 0.0)
        }
        self.lblNoResult.isHidden = true
        self.collectionView.es_addPullToRefresh {
            self.currentIndex = 0
            self.trendsAPI(didFinishedWithResult: { count in
                self.collectionView.es_stopPullToRefresh()
                if count > 0 {
                    self.collectionView.reloadData()
                }else{
                    self.lblNoResult.isHidden = false
                }
            })
        }
        self.collectionView.es_startPullToRefresh()
        self.collectionView.es_addInfiniteScrolling {
            if self.currentMode == .search{
                self.loadMore()
            }else{
                self.collectionView.es_stopLoadingMore()
            }
        }
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        self.collectionView.reloadData()
    }
    func clickOnTitleButton(titleButton: UIButton) {
        self.collectionView?.scrollToItem(at: IndexPath(row: 0, section: 0),
                                          at: .top,
                                          animated: true)
    }
    private func loadMore() {
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            if self.currentIndex < 100{
                self.currentIndex += 10
                self.searchAPI(searchKey: self.currentSearchKey, didFinishedWithResult: { (count) in
                    if count < 10{
                        self.collectionView.es_noticeNoMoreData()
                    }
                    self.collectionView.reloadData()
                })
                self.collectionView.es_stopLoadingMore()
            }else{
                self.collectionView.es_noticeNoMoreData()
            }
        }
    }
    func trendsAPI(didFinishedWithResult: @escaping(Int) -> Void){
        self.currentMode = .trends
        self.lblNoResult.isHidden = true
        let apiRequest = request(String(format:"%@%@",Constants.API_URL_DEVELOPMENT,Constants.getTrendsV2),
                                 method: .post, parameters: [Constants.USER_ID_KEY : Me.user.id,
                                                             Constants.USER_SESSION_KEY : Me.session_id,
                                                             Constants.INDEX_KEY : index])
        
        apiRequest.responseString(completionHandler: { response in
            do{
                print(response)
                let jsonResponse = try JSONSerialization.jsonObject(with: response.data!, options: []) as! [String : Any]
                let status = jsonResponse[Constants.STATUS_KEY] as! String
                
                if status == "1"{
                    let result = jsonResponse[Constants.RESULT_KEY] as! [AnyObject]
                    if result.count > 0 {
                        self.names = result
                        self.filteredNames = self.names
                    }else{
                        self.lblNoResult.isHidden = false
                    }
                    didFinishedWithResult(result.count)
                }else {
                    didFinishedWithResult(0)
                    let alertController = UIAlertController(title: "ReciFoto", message: jsonResponse["message"] as? String, preferredStyle: UIAlertControllerStyle.alert)
                    alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
                    self.present(alertController, animated: true, completion: nil)
                }
            }catch{
                didFinishedWithResult(0)
                print("Error Parsing JSON from get_trends")
            }
            
        })
    }
    func searchAPI(searchKey: String,  didFinishedWithResult: @escaping(Int) -> Void){
        self.currentMode = .search
        self.lblNoResult.isHidden = true
        self.currentSearchKey = searchKey
        NVActivityIndicatorPresenter.sharedInstance.startAnimating(ActivityData())
        let apiRequest = request(String(format:"%@%@",Constants.API_URL_DEVELOPMENT,Constants.recipeSearchV2),
                                 method: .post, parameters: [Constants.USER_ID_KEY : Me.user.id,
                                                             Constants.USER_SESSION_KEY : Me.session_id,
                                                             Constants.SEARCH_KEY : searchKey,
                                                             Constants.INDEX_KEY : self.currentIndex])
        
        apiRequest.responseString(completionHandler: { response in
            do{
                let jsonResponse = try JSONSerialization.jsonObject(with: response.data!, options: []) as! [String : Any]
                let status = jsonResponse[Constants.STATUS_KEY] as! String
                
                if status == "1"{
                    let result = jsonResponse[Constants.RESULT_KEY] as! [AnyObject]
                    if result.count > 0 {
                        for recipe in result{
                            self.names.append(recipe)
                        }
//                        self.names = result
                        self.filteredNames = self.names
                        print(self.names)
                    }else{
                        if self.currentIndex == 0{
                            self.lblNoResult.isHidden = false
                        }
                    }
                    didFinishedWithResult(result.count)
                }else {
                    didFinishedWithResult(0)
                    let alertController = UIAlertController(title: "ReciFoto", message: jsonResponse["message"] as? String, preferredStyle: UIAlertControllerStyle.alert)
                    alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
                    self.present(alertController, animated: true, completion: nil)
                }
                NVActivityIndicatorPresenter.sharedInstance.stopAnimating()
            }catch{
                NVActivityIndicatorPresenter.sharedInstance.stopAnimating()
                didFinishedWithResult(0)
                print("Error Parsing JSON from get_search")
            }
            
        })
    }
    // MARK: - Layout
    
    internal override func viewDidLayoutSubviews() {
        
        super.viewDidLayoutSubviews()
        
        guard self.readyForPresentation == false else {
            
            return
        }
        
        self.readyForPresentation = true
        
        let searchItemIndexPath = IndexPath(item: 0, section: 0)
        self.collectionView.contentOffset = CGPoint(x: 0.0, y: self.collectionView(self.collectionView, layout: self.collectionView.collectionViewLayout, sizeForItemAt: searchItemIndexPath).height)
    }
    
    // MARK: - UICollectionViewDataSource
    
    internal func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        switch indexPath.section {
            
        case 0:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SearchCollectionViewCell.identifier", for: indexPath) as! SearchCollectionViewCell
            
            cell.searchBar.delegate = self
            cell.searchBar.searchBarStyle = .minimal
            cell.searchBar.placeholder = "Search"
            
            return cell
            
        case 1:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TextCollectionViewCell.identifier", for: indexPath) as! TextCollectionViewCell
            cell.colorView.alpha = 1
            cell.imageView.alpha = 0
            cell.colorView.layer.cornerRadius = 10.0
            cell.colorView.layer.masksToBounds = true
            cell.label.textColor = UIColor.white
            cell.label.textAlignment = .center

            if currentMode == .trends {
                let name = self.filteredNames[indexPath.item] as! [String : String]
                
                cell.colorView.backgroundColor = Constants.colors[indexPath.item]
                
                cell.label.text = name[Constants.RECIPE_TITLE_KEY]
            }else{
                let name = self.filteredNames[indexPath.item] as! NSDictionary
                let recipe = Recipe(dict: name)
                
                cell.colorView.backgroundColor = Constants.colors[indexPath.item % 12]
                
                cell.label.text = recipe.title
            }
            
            return cell
            
        default:
            assert(false)
        }
        return UICollectionViewCell()
    }
    
    internal func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch indexPath.section {
            
        case 0:
            break
        case 1:
            if currentMode == .trends {
                let name = self.filteredNames[indexPath.item] as! [String : String]
                self.names.removeAll()
                self.filteredNames.removeAll()
                self.currentIndex = 0
                self.searchAPI(searchKey: name[Constants.RECIPE_TITLE_KEY]!) { count in
                    self.collectionView.reloadData()
                }
            }else{
                let name = self.filteredNames[indexPath.item] as! NSDictionary
                let recipe = Recipe(dict: name)
                if let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "recipeVC") as? RecipeViewController {
                    if let navigator = navigationController {
                        viewController.recipe = recipe
                        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
                        navigator.pushViewController(viewController, animated: true)
                    }
                }
            }
            
        default:
            assert(false)
        }
    }
    
    internal func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        switch section {
            
        case 0:
            return 1
            
        case 1:
            return self.filteredNames.count
        default:
            assert(false)
        }
        return 0
    }
    
    internal func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    
    internal func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        
        switch section {
            
        case 0:
            return UIEdgeInsets.zero
            
        case 1:
            return UIEdgeInsets(top: 10.0, left: 10.0, bottom: 10.0, right: 10.0)
            
        default:
            assert(false)
        }
        return UIEdgeInsets.zero
    }
    
    internal func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        
        return 5.0
    }
    
    internal func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        
        return 5.0
    }
    
    internal func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        switch indexPath.section {
            
        case 0:
            let itemWidth = collectionView.frame.width
            let itemHeight: CGFloat = 44.0
            
            return CGSize(width: itemWidth, height: itemHeight)
            
        case 1:
            let numberOfItemsInLine: CGFloat = 3
            
            let inset = self.collectionView(collectionView, layout: collectionViewLayout, insetForSectionAt: indexPath.section)
            let minimumInteritemSpacing = self.collectionView(collectionView, layout: collectionViewLayout, minimumInteritemSpacingForSectionAt: indexPath.section)
            
            let itemWidth = (collectionView.frame.width - inset.left - inset.right - minimumInteritemSpacing * (numberOfItemsInLine - 1)) / numberOfItemsInLine
            let itemHeight = itemWidth
            
            return CGSize(width: itemWidth, height: itemHeight)
            
        default:
            assert(false)
        }
        return CGSize.zero
    }
    
    // MARK: - UIScrollViewDelegate
    
    internal func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        
        guard scrollView === self.collectionView else {
            
            return
        }
        
        let indexPath = IndexPath(item: 0, section: 0)
        guard let cell = self.collectionView.cellForItem(at: indexPath) as? SearchCollectionViewCell else {
            
            return
        }
        
        guard cell.searchBar.isFirstResponder else {
            
            return
        }
        
        cell.searchBar.resignFirstResponder()
    }
    
    // MARK: - UISearchBarDelegate
    
    internal func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        let oldFilteredNames = self.filteredNames
        if searchText.isEmpty {
            self.filteredNames = self.names
        }else {
            if currentMode == .search{
                self.filteredNames = self.names.filter({ (name) -> Bool in
                    if ((name[Constants.RECIPE_KEY] as! NSDictionary)[Constants.RECIPE_TITLE_KEY] as! String).contains(searchText){
                        return true
                    }else{
                        return false
                    }
                })
            }else{
                self.filteredNames = self.names.filter({ (name) -> Bool in
                    if (name[Constants.RECIPE_TITLE_KEY] as! String).contains(searchText){
                        return true
                    }else{
                        return false
                    }
                })
            }
        }
        
        self.collectionView.performBatchUpdates({
            for (oldIndex, oldName) in oldFilteredNames.enumerated() {
                if self.filteredNames.contains(where: { (name) -> Bool in
                    if oldName as! NSDictionary == name as! NSDictionary{
                        return true
                    }else{
                        return false
                    }
                }) == false{
                    let indexPath = IndexPath(item: oldIndex, section: 1)
                    self.collectionView.deleteItems(at: [indexPath])
                }
            }
            for (index, name) in self.filteredNames.enumerated() {
                if oldFilteredNames.contains(where: { (oldName) -> Bool in
                    if oldName as! NSDictionary == name as! NSDictionary{
                        return true
                    }else{
                        return false
                    }
                }) == false{
                    let indexPath = IndexPath(item: index, section: 1)
                    self.collectionView.insertItems(at: [indexPath])
                }
            }
            
        }, completion: nil)
    }
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(true, animated: true)
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(false, animated: true)
    }
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchBar.resignFirstResponder()
    }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        self.names.removeAll()
        self.filteredNames.removeAll()
        self.currentIndex = 0
        self.searchAPI(searchKey: searchBar.text!) { count in
            self.collectionView.reloadData()
        }
        searchBar.resignFirstResponder()
        searchBar.text = ""
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
