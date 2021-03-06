import UIKit

class CountriesCell: UITableViewCell, NibLoadable {

    // MARK: - Properties

    @IBOutlet weak var topSeparatorLine: UIView!
    @IBOutlet weak var subtitleStackView: UIStackView!
    @IBOutlet weak var rowsStackView: UIStackView!
    @IBOutlet weak var itemSubtitleLabel: UILabel!
    @IBOutlet weak var dataSubtitleLabel: UILabel!
    @IBOutlet weak var bottomSeparatorLine: UIView!

    // If the subtitles are not shown, this is active.
    @IBOutlet weak var rowsStackViewTopConstraint: NSLayoutConstraint!
    // If the subtitles are shown, this is active.
    @IBOutlet weak var rowsStackViewTopConstraintWithSubtitles: NSLayoutConstraint!

    private weak var siteStatsPeriodDelegate: SiteStatsPeriodDelegate?
    private var dataRows = [StatsTotalRowData]()
    private typealias Style = WPStyleGuide.Stats
    private var forDetails = false

    // MARK: - Configure

    func configure(itemSubtitle: String,
                   dataSubtitle: String,
                   dataRows: [StatsTotalRowData],
                   siteStatsPeriodDelegate: SiteStatsPeriodDelegate? = nil,
                   forDetails: Bool = false) {
        itemSubtitleLabel.text = itemSubtitle
        dataSubtitleLabel.text = dataSubtitle
        self.dataRows = dataRows
        self.siteStatsPeriodDelegate = siteStatsPeriodDelegate
        self.forDetails = forDetails
        bottomSeparatorLine.isHidden = forDetails

        // TODO: in xib when add map:
        // - unhide Map View
        // - Top Separator Line: enable Top Space to Map View constraint
        // - Top Separator Line: remove Top Space to Superview constraint

        if !forDetails {
        addRows(dataRows,
                toStackView: rowsStackView,
                forType: .period,
                limitRowsDisplayed: true,
                viewMoreDelegate: self)
        }

        setSubtitleVisibility()
        applyStyles()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        removeRowsFromStackView(rowsStackView)
    }

}

private extension CountriesCell {

    func applyStyles() {
        Style.configureCell(self)
        Style.configureLabelAsSubtitle(itemSubtitleLabel)
        Style.configureLabelAsSubtitle(dataSubtitleLabel)
        Style.configureViewAsSeparator(topSeparatorLine)
        Style.configureViewAsSeparator(bottomSeparatorLine)
    }

    func setSubtitleVisibility() {

        if forDetails {
            subtitleStackView.isHidden = false
            rowsStackView.isHidden = true
            return
        }

        let showSubtitles = dataRows.count > 0
        subtitleStackView.isHidden = !showSubtitles
        rowsStackViewTopConstraint.isActive = !showSubtitles
        rowsStackViewTopConstraintWithSubtitles.isActive = showSubtitles
    }

}

// MARK: - ViewMoreRowDelegate

extension CountriesCell: ViewMoreRowDelegate {

    func viewMoreSelectedForStatSection(_ statSection: StatSection) {
        siteStatsPeriodDelegate?.viewMoreSelectedForStatSection?(statSection)
    }

}
