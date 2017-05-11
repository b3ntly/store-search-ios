//
//  SearchResultCell.swift
//  StoreSearch
//
//  Created by Benjamin jones on 5/10/17.
//  Copyright © 2017 Benjamin jones. All rights reserved.
//

import UIKit

class SearchResultCell: UITableViewCell {
    @IBOutlet weak var artworkImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    
    var downloadTask: URLSessionDownloadTask?

    override func awakeFromNib() {
        super.awakeFromNib()
        let selectedView = UIView(frame: CGRect.zero)
        selectedView.backgroundColor = UIColor(red: 20/255, green: 160/255, blue: 160/255, alpha: 1)
        selectedBackgroundView = selectedView
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        downloadTask?.cancel()
        downloadTask = nil
    }

    func configure(for searchResult: SearchResult){
        nameLabel.text = searchResult.name
        artistLabel.text = (searchResult.artistName.isEmpty) ? "Unknown": String(format: "%@ (%@)", searchResult.artistName, searchResult.kind)
        
        // configure a default URL and update it if the actuall image url is present
        artworkImageView.image = UIImage(named: "Placeholder")
        if let smallURL = URL(string: searchResult.artworkSmallURL){
            downloadTask = artworkImageView.loadImage(url: smallURL)
        }
    }
}
