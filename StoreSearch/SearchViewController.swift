//
//  ViewController.swift
//  StoreSearch
//
//  Created by Benjamin jones on 5/9/17.
//  Copyright © 2017 Benjamin jones. All rights reserved.
//

import UIKit

class SearchViewController: UIViewController {
    
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    
    @IBAction func segmentChanged(_ sender: UISegmentedControl) {
        performSearch()
    }
    
    var searchResults: [SearchResult] = []
    var hasSearched: Bool = false
    var dataTask: URLSessionDataTask?
    var isLoading: Bool = false
    
    struct TableViewCellIdentifiers {
        static let searchResultCell = "SearchResultCell"
        static let nothingFoundCell = "NothingFoundCell"
        static let loadingCell = "LoadingCell"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // programatically fix some styling issues
        tableView.contentInset = UIEdgeInsets(top: 108, left: 0, bottom: 0, right: 0)
        tableView.rowHeight = 80
        
        let cellNib = UINib(nibName: TableViewCellIdentifiers.searchResultCell, bundle: nil)
        let notFoundCellNib = UINib(nibName: TableViewCellIdentifiers.nothingFoundCell, bundle: nil)
        let loadingCellNib = UINib(nibName: TableViewCellIdentifiers.loadingCell, bundle: nil)
        
        tableView.register(cellNib, forCellReuseIdentifier: TableViewCellIdentifiers.searchResultCell)
        tableView.register(notFoundCellNib, forCellReuseIdentifier: TableViewCellIdentifiers.nothingFoundCell)
        tableView.register(loadingCellNib, forCellReuseIdentifier: TableViewCellIdentifiers.loadingCell)
        
        searchBar.becomeFirstResponder()
        
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func iTunesURL(searchText: String, category: Int) -> URL {
        let entityName: String
        
        switch category {
        case 1: entityName = "musicTrack"
        case 2: entityName = "software"
        case 3: entityName = "ebook"
        default: entityName = ""
        }
        
        let escapedSearchText = searchText.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!
        let urlString = String(format: "https://itunes.apple.com/search?term=%@&limit=200&entity=%@", escapedSearchText, entityName)
        return URL(string: urlString)!
    }
    
    func parse(json: Data) -> [String: Any]? {
        do {
            return try JSONSerialization.jsonObject(with: json, options: []) as? [String: Any]
        } catch {
            return nil
        }
    }
    
    func parse(dictionary: [String: Any]) -> [SearchResult]{
        guard let array = dictionary["results"] as? [Any] else {
            showError(message: "Failed to parse results from iTunes store.")
            return []
        }
        
        var searchResults: [SearchResult] = []
        
        for resultDict in array {
            if let resultDict = resultDict as? [String: Any] {
                var searchResult: SearchResult?
                
                if let wrapperType = resultDict["wrapperType"] as? String {
                    switch wrapperType {
                    case "track":
                        searchResult = SearchResult.from(track: resultDict)
                    case "audiobook":
                        searchResult = SearchResult.from(audiobook: resultDict)
                    case "software":
                        searchResult = SearchResult.from(software: resultDict)
                    
                    default: break
                    }
                    
                // normalize a descrempancy in JSON structure where "wrapperType" is not returned but instead stored as the value of "kind"
                } else if let kind = resultDict["kind"] as? String, kind == "ebook" {
                    searchResult = SearchResult.from(ebook: resultDict)
                }
                
                if let result = searchResult {
                    searchResults.append(result)
                }
            }
        }
        
        return searchResults
    }
    
    func showError(message: String){
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: "Ok", style: .default, handler: nil)
        alert.addAction(action)
        present(alert, animated: true, completion: nil)
    }
}

extension SearchViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        performSearch()
    }
    
    func performSearch(){
        hasSearched = true
        
        // hide the keyboard
        searchBar.resignFirstResponder()
        searchResults = []
        
        if !searchBar.text!.isEmpty {
            dataTask?.cancel()
            isLoading = true
            tableView.reloadData() // reload the table so the loading spinner is displayed
            

            let url = self.iTunesURL(searchText: searchBar.text!, category: segmentedControl.selectedSegmentIndex)
            let session = URLSession.shared
            
            dataTask = session.dataTask(with: url) {
                [weak self] data, response, error in
                
                guard error == nil else {
                    // -999 represents a canceled request and should not throw an error
                    if let error = error as? NSError, error.code == -999 {
                        return
                    }
                    
                    let message = error?.localizedDescription
                    self?.searchFinished(error: message!)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self?.searchFinished(error: "Query to iTunes did not return a valid response.")
                    return
                }
                
                // validate that the httpResponse >= 200 and <= 299
                guard 200 ... 299 ~= httpResponse.statusCode else {
                    self?.searchFinished(error: "Query to iTunes failed with HTTP code \(httpResponse.statusCode)")
                    return
                }
                
                // handle the validated http response body
                if let data = data, let jsonDictionary = self?.parse(json: data){
                    self?.searchResults = (self?.parse(dictionary: jsonDictionary))!
                    self?.searchResults.sort(by: <)
        
                    DispatchQueue.main.async{ self?.searchFinished() }
                    return
                }
                
                self?.searchFinished(error: "Failed to parse JSON response from iTunes.")
                
            }
            
            dataTask?.resume()
        }
    }
    
    func searchFinished(error: String){
        self.showError(message: error)
        self.searchFinished()
    }
    
    func searchFinished(){
        self.isLoading = false
        self.tableView.reloadData()
    }
    
    private func position(for bar: UIBarPosition) -> UIBarPosition {
        return .topAttached
    }
}

extension SearchViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isLoading {
            return 1
        }
        
        // If no searches have been attempted do not show a "Nothing found!" cell
        if !hasSearched {
            return 0
        }
        
        // Show at least one cell so that we may display a "Nothing found!" if nothing was found
        if searchResults.count == 0 {
            return 1
        }
        
        return searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if isLoading {
            let cell = tableView.dequeueReusableCell(withIdentifier: TableViewCellIdentifiers.loadingCell, for: indexPath)
            let spinner = cell.viewWithTag(100) as! UIActivityIndicatorView
            spinner.startAnimating()
            return cell
        }
        
        if searchResults.count == 0 {
            return tableView.dequeueReusableCell(withIdentifier: TableViewCellIdentifiers.nothingFoundCell, for: indexPath) 
        }
        
        let searchResult = searchResults[indexPath.row]
        
        let cell = tableView.dequeueReusableCell(withIdentifier: TableViewCellIdentifiers.searchResultCell, for: indexPath) as! SearchResultCell
        cell.configure(for: searchResult)
        return cell
    }
}

extension SearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        return (searchResults.count == 0 || isLoading) ? nil : indexPath
    }
}
