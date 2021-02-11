import Foundation
import Display
import UIKit
import AsyncDisplayKit
import TelegramPresentationData
import TelegramStringFormatting
import SegmentedControlNode

public final class DatePickerTheme: Equatable {
    public let backgroundColor: UIColor
    public let textColor: UIColor
    public let secondaryTextColor: UIColor
    public let accentColor: UIColor
    public let disabledColor: UIColor
    public let selectionColor: UIColor
    public let selectionTextColor: UIColor
    public let separatorColor: UIColor
    public let segmentedControlTheme: SegmentedControlTheme
    
    public init(backgroundColor: UIColor, textColor: UIColor, secondaryTextColor: UIColor, accentColor: UIColor, disabledColor: UIColor, selectionColor: UIColor, selectionTextColor: UIColor, separatorColor: UIColor, segmentedControlTheme: SegmentedControlTheme) {
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.secondaryTextColor = secondaryTextColor
        self.accentColor = accentColor
        self.disabledColor = disabledColor
        self.selectionColor = selectionColor
        self.selectionTextColor = selectionTextColor
        self.separatorColor = separatorColor
        self.segmentedControlTheme = segmentedControlTheme
    }
    
    public static func ==(lhs: DatePickerTheme, rhs: DatePickerTheme) -> Bool {
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.textColor != rhs.textColor {
            return false
        }
        if lhs.secondaryTextColor != rhs.secondaryTextColor {
            return false
        }
        if lhs.accentColor != rhs.accentColor {
            return false
        }
        if lhs.selectionColor != rhs.selectionColor {
            return false
        }
        if lhs.selectionTextColor != rhs.selectionTextColor {
            return false
        }
        if lhs.separatorColor != rhs.separatorColor {
            return false
        }
        return true
    }
}

public extension DatePickerTheme {
    convenience init(theme: PresentationTheme) {
        self.init(backgroundColor: theme.list.itemBlocksBackgroundColor, textColor: theme.list.itemPrimaryTextColor, secondaryTextColor: theme.list.itemSecondaryTextColor, accentColor: theme.list.itemAccentColor, disabledColor: theme.list.itemDisabledTextColor, selectionColor: theme.list.itemCheckColors.fillColor, selectionTextColor: theme.list.itemCheckColors.foregroundColor, separatorColor: theme.list.itemBlocksSeparatorColor, segmentedControlTheme: SegmentedControlTheme(theme: theme))
    }
}

private let telegramReleaseDate = Date(timeIntervalSince1970: 1376438400.0)
private let upperLimitDate = Date(timeIntervalSince1970: Double(Int32.max - 1))

private let controlFont = Font.regular(17.0)
private let dayFont = Font.regular(13.0)
private let dateFont = Font.with(size: 17.0, design: .regular, traits: .monospacedNumbers)
private let selectedDateFont = Font.with(size: 17.0, design: .regular, traits: [.bold, .monospacedNumbers])

private let calendar = Calendar(identifier: .gregorian)

private func monthForDate(_ date: Date) -> Date {
    var components = calendar.dateComponents([.year, .month], from: date)
    components.hour = 0
    components.minute = 0
    components.second = 0
    return calendar.date(from: components)!
}

private func generateSmallArrowImage(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 7.0, height: 12.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.beginPath()
        context.move(to: CGPoint(x: 1.0, y: 1.0))
        context.addLine(to: CGPoint(x: size.width - 1.0, y: size.height / 2.0))
        context.addLine(to: CGPoint(x: 1.0, y: size.height - 1.0))
        context.strokePath()
    })
}

private func generateNavigationArrowImage(color: UIColor, mirror: Bool) -> UIImage? {
    return generateImage(CGSize(width: 10.0, height: 17.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.beginPath()
        if mirror {
            context.translateBy(x: 5.0, y: 8.5)
            context.scaleBy(x: -1.0, y: 1.0)
            context.translateBy(x: -5.0, y: -8.5)
        }
        context.move(to: CGPoint(x: 1.0, y: 1.0))
        context.addLine(to: CGPoint(x: size.width - 1.0, y: size.height / 2.0))
        context.addLine(to: CGPoint(x: 1.0, y: size.height - 1.0))
        context.strokePath()
    })
}

private func yearRange(for state: DatePickerNode.State) -> Range<Int> {
    let minYear = calendar.component(.year, from: state.minDate)
    let maxYear = calendar.component(.year, from: state.maxDate)
    return minYear ..< maxYear + 1
}

public final class DatePickerNode: ASDisplayNode {
    class MonthNode: ASDisplayNode {
        let month: Date
        
        var theme: DatePickerTheme {
            didSet {
                self.selectionNode.image = generateStretchableFilledCircleImage(diameter: 44.0, color: self.theme.selectionColor)
                if let size = self.validSize {
                    self.updateLayout(size: size)
                }
            }
        }
        
        var maximumDate: Date?
        var minimumDate: Date?
        var date: Date?
        
        private var validSize: CGSize?
        
        private let selectionNode: ASImageNode
        private let dateNodes: [ImmediateTextNode]
        
        private let firstWeekday: Int
        private let startWeekday: Int
        private let numberOfDays: Int
        
        init(theme: DatePickerTheme, month: Date, minimumDate: Date?, maximumDate: Date?, date: Date?) {
            self.theme = theme
            self.month = month
            self.minimumDate = minimumDate
            self.maximumDate = maximumDate
            self.date = date
            
            self.selectionNode = ASImageNode()
            self.selectionNode.displaysAsynchronously = false
            self.selectionNode.displayWithoutProcessing = true
            self.selectionNode.image = generateStretchableFilledCircleImage(diameter: 44.0, color: theme.selectionColor)
            
            self.dateNodes = (0..<42).map { _ in ImmediateTextNode() }
            
            let components = calendar.dateComponents([.year, .month], from: month)
            let startDayDate = calendar.date(from: components)!
            
            self.firstWeekday = calendar.firstWeekday
            self.startWeekday = calendar.dateComponents([.weekday], from: startDayDate).weekday!
            self.numberOfDays = calendar.range(of: .day, in: .month, for: month)!.count
            
            super.init()
                        
            self.addSubnode(self.selectionNode)
            self.dateNodes.forEach { self.addSubnode($0) }
        }
        
        func dateAtPoint(_ point: CGPoint) -> Int32? {
            var day: Int32 = 0
            for node in self.dateNodes {
                if node.isHidden {
                    continue
                }
                day += 1
                
                if node.frame.insetBy(dx: -15.0, dy: -15.0).contains(point) {
                    return day
                }
            }
            return nil
        }
                
        func updateLayout(size: CGSize) {
            var weekday = self.firstWeekday
            var started = false
            var ended = false
            var count = 0
            
            let sideInset: CGFloat = 12.0
            let cellSize: CGFloat = floor((size.width - sideInset * 2.0) / 7.0)
            
            self.selectionNode.isHidden = true
            for i in 0 ..< 42 {
                let row: Int = Int(floor(Float(i) / 7.0))
                let col: Int = i % 7
                
                if !started && weekday == self.startWeekday {
                    started = true
                }
                weekday += 1
                
                let textNode = self.dateNodes[i]
                if started && !ended {
                    textNode.isHidden = false
                    count += 1
                    
                    var isAvailableDate = true
                    var components = calendar.dateComponents([.year, .month], from: self.month)
                    components.day = count
                    components.hour = 0
                    components.minute = 0
                    let date = calendar.date(from: components)!
                    
                    if let minimumDate = self.minimumDate {
                        if date < minimumDate {
                            isAvailableDate = false
                        }
                    }
                    if let maximumDate = self.maximumDate {
                        if date > maximumDate {
                            isAvailableDate = false
                        }
                    }
                    let isToday = calendar.isDateInToday(date)
                    let isSelected = self.date.flatMap { calendar.isDate(date, equalTo: $0, toGranularity: .day) } ?? false

                    let color: UIColor
                    if isSelected {
                        color = self.theme.selectionTextColor
                    } else if isToday {
                        color = self.theme.accentColor
                    } else if !isAvailableDate {
                        color = self.theme.disabledColor
                    } else {
                        color = self.theme.textColor
                    }
                    
                    textNode.attributedText = NSAttributedString(string: "\(count)", font: isSelected ? selectedDateFont : dateFont, textColor: color)

                    let textSize = textNode.updateLayout(size)
                    
                    let cellFrame = CGRect(x: sideInset + CGFloat(col) * cellSize, y: 0.0 + CGFloat(row) * cellSize, width: cellSize, height: cellSize)
                    let textFrame = CGRect(origin: CGPoint(x: cellFrame.minX + floor((cellFrame.width - textSize.width) / 2.0), y: cellFrame.minY + floor((cellFrame.height - textSize.height) / 2.0)), size: textSize)
                    textNode.frame = textFrame
                    
                    if isSelected {
                        self.selectionNode.isHidden = false
                        let selectionSize = CGSize(width: 44.0, height: 44.0)
                        self.selectionNode.frame = CGRect(origin: CGPoint(x: cellFrame.minX + floor((cellFrame.width - selectionSize.width) / 2.0), y: cellFrame.minY + floor((cellFrame.height - selectionSize.height) / 2.0)), size: selectionSize)
                    }
                    
                    if count == self.numberOfDays {
                        ended = true
                    }
                } else {
                    textNode.isHidden = true
                }
            }
        }
    }
    
    struct State {
        let minDate: Date
        let maxDate: Date
        let date: Date
        
        let displayingMonthSelection: Bool
        let selectedMonth: Date
    }
    
    private var state: State
    
    private var theme: DatePickerTheme
    private let strings: PresentationStrings
    
    private let timeTitleNode: ImmediateTextNode
    private let timePickerNode: TimePickerNode
    private let timeSeparatorNode: ASDisplayNode
        
    private let dayNodes: [ImmediateTextNode]
    private var currentIndex = 0
    private var months: [Date] = []
    private var monthNodes: [Date: MonthNode] = [:]
    private let contentNode: ASDisplayNode
    
    private let pickerBackgroundNode: ASDisplayNode
    private var pickerNode: MonthPickerNode
    
    private let monthButtonNode: HighlightTrackingButtonNode
    private let monthTextNode: ImmediateTextNode
    private let monthArrowNode: ASImageNode
    private let previousButtonNode: HighlightableButtonNode
    private let nextButtonNode: HighlightableButtonNode
    
    private var transitionFraction: CGFloat = 0.0
    
    private var gestureRecognizer: UIPanGestureRecognizer?
    private var gestureSelectedIndex: Int?
    
    private var validLayout: CGSize?
    
    public var valueUpdated: ((Date) -> Void)?
    
    public var minimumDate: Date {
        get {
            return self.state.minDate
        }
        set {
            guard newValue != self.minimumDate else {
                return
            }
            
            let updatedState = State(minDate: newValue, maxDate: self.state.maxDate, date: self.state.date, displayingMonthSelection: self.state.displayingMonthSelection, selectedMonth: self.state.selectedMonth)
            self.updateState(updatedState, animated: false)
            
            self.pickerNode.minimumDate = newValue
            
            if let size = self.validLayout {
                let _ = self.updateLayout(size: size, transition: .immediate)
            }
        }
    }
    
    public var maximumDate: Date {
        get {
            return self.state.maxDate
        }
        set {
            guard newValue != self.maximumDate else {
                return
            }
            
            let updatedState = State(minDate: self.state.minDate, maxDate: newValue, date: self.state.date, displayingMonthSelection: self.state.displayingMonthSelection, selectedMonth: self.state.selectedMonth)
            self.updateState(updatedState, animated: false)
            
            self.pickerNode.maximumDate = newValue
            
            if let size = self.validLayout {
                let _ = self.updateLayout(size: size, transition: .immediate)
            }
        }
    }
    
    public var date: Date {
        get {
            return self.state.date
        }
        set {
            guard newValue != self.date else {
                return
            }
            
            let updatedState = State(minDate: self.state.minDate, maxDate: self.state.maxDate, date: newValue, displayingMonthSelection: self.state.displayingMonthSelection, selectedMonth: self.state.selectedMonth)
            self.updateState(updatedState, animated: false)
            
            if let size = self.validLayout {
                let _ = self.updateLayout(size: size, transition: .immediate)
            }
        }
    }
    
    public init(theme: DatePickerTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat) {
        self.theme = theme
        self.strings = strings
        self.state = State(minDate: telegramReleaseDate, maxDate: upperLimitDate, date: Date(), displayingMonthSelection: false, selectedMonth: monthForDate(Date()))
                
        self.timeTitleNode = ImmediateTextNode()
        self.timeTitleNode.attributedText = NSAttributedString(string: "Time", font: Font.regular(17.0), textColor: theme.textColor)
        
        self.timePickerNode = TimePickerNode(theme: theme, dateTimeFormat: dateTimeFormat, date: self.state.date)
    
        self.timeSeparatorNode = ASDisplayNode()
        self.timeSeparatorNode.backgroundColor = theme.separatorColor
        
        self.dayNodes = (0..<7).map { _ in ImmediateTextNode() }
        
        self.contentNode = ASDisplayNode()
        
        self.pickerBackgroundNode = ASDisplayNode()
        self.pickerBackgroundNode.alpha = 0.0
        self.pickerBackgroundNode.backgroundColor = theme.backgroundColor
        self.pickerBackgroundNode.isUserInteractionEnabled = false
        
        var monthChangedImpl: ((Date) -> Void)?
        self.pickerNode = MonthPickerNode(theme: theme, strings: strings, date: self.state.date, yearRange: yearRange(for: self.state), valueChanged: { date in
            monthChangedImpl?(date)
        })
        self.pickerNode.minimumDate = self.state.minDate
        self.pickerNode.maximumDate = self.state.maxDate
        
        self.monthButtonNode = HighlightTrackingButtonNode()
        self.monthTextNode = ImmediateTextNode()
        self.monthArrowNode = ASImageNode()
        self.monthArrowNode.displaysAsynchronously = false
        self.monthArrowNode.displayWithoutProcessing = true
        
        self.previousButtonNode = HighlightableButtonNode()
        self.previousButtonNode.hitTestSlop = UIEdgeInsets(top: -6.0, left: -10.0, bottom: -6.0, right: -10.0)
        self.nextButtonNode = HighlightableButtonNode()
        self.nextButtonNode.hitTestSlop = UIEdgeInsets(top: -6.0, left: -10.0, bottom: -6.0, right: -10.0)
        
        super.init()
        
        self.clipsToBounds = true
        self.backgroundColor = theme.backgroundColor
        
        self.addSubnode(self.timeTitleNode)
        self.addSubnode(self.timePickerNode)
        
        self.addSubnode(self.contentNode)
                
        self.dayNodes.forEach { self.addSubnode($0) }
        
        self.addSubnode(self.previousButtonNode)
        self.addSubnode(self.nextButtonNode)
        
        self.addSubnode(self.pickerBackgroundNode)
        self.pickerBackgroundNode.addSubnode(self.pickerNode)
        
        self.addSubnode(self.monthTextNode)
        self.addSubnode(self.monthArrowNode)
        self.addSubnode(self.monthButtonNode)
        
        self.monthArrowNode.image = generateSmallArrowImage(color: theme.accentColor)
        self.previousButtonNode.setImage(generateNavigationArrowImage(color: theme.accentColor, mirror: true), for: .normal)
        self.previousButtonNode.setImage(generateNavigationArrowImage(color: theme.disabledColor, mirror: true), for: .disabled)
        self.nextButtonNode.setImage(generateNavigationArrowImage(color: theme.accentColor, mirror: false), for: .normal)
        self.nextButtonNode.setImage(generateNavigationArrowImage(color: theme.disabledColor, mirror: false), for: .disabled)
        
        self.setupItems()
        
        self.monthButtonNode.addTarget(self, action: #selector(self.monthButtonPressed), forControlEvents: .touchUpInside)
        self.monthButtonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.monthTextNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.monthTextNode.alpha = 0.4
                    strongSelf.monthArrowNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.monthArrowNode.alpha = 0.4
                } else {
                    strongSelf.monthTextNode.alpha = 1.0
                    strongSelf.monthTextNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.monthArrowNode.alpha = 1.0
                    strongSelf.monthArrowNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.previousButtonNode.addTarget(self, action: #selector(self.previousButtonPressed), forControlEvents: .touchUpInside)
        self.nextButtonNode.addTarget(self, action: #selector(self.nextButtonPressed), forControlEvents: .touchUpInside)
        
        self.timePickerNode.valueChanged = { [weak self] date in
            if let strongSelf = self {
                let updatedState = State(minDate: strongSelf.state.minDate, maxDate: strongSelf.state.maxDate, date: date, displayingMonthSelection: strongSelf.state.displayingMonthSelection, selectedMonth: strongSelf.state.selectedMonth)
                strongSelf.updateState(updatedState, animated: false)
                
                strongSelf.valueUpdated?(date)
            }
        }
        
        monthChangedImpl = { [weak self] date in
            if let strongSelf = self {
                let updatedState = State(minDate: strongSelf.state.minDate, maxDate: strongSelf.state.maxDate, date: date, displayingMonthSelection: strongSelf.state.displayingMonthSelection, selectedMonth: monthForDate(date))
                strongSelf.updateState(updatedState, animated: false)
                
                strongSelf.valueUpdated?(date)
            }
        }
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.view.disablesInteractiveTransitionGestureRecognizer = true
        
        self.contentNode.view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:))))
        self.contentNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    private func updateState(_ state: State, animated: Bool) {
        let previousState = self.state
        self.state = state
        
        if previousState.minDate != state.minDate || previousState.maxDate != state.maxDate {
            self.pickerNode.yearRange = yearRange(for: state)
            self.setupItems()
        } else if previousState.selectedMonth != state.selectedMonth {
            for i in 0 ..< self.months.count {
                if self.months[i].timeIntervalSince1970 > state.selectedMonth.timeIntervalSince1970 {
                    self.currentIndex = max(0, min(self.months.count - 1, i - 1))
                    break
                }
            }
        }
        self.pickerNode.date = self.state.date
        
        if let size = self.validLayout {
            self.updateLayout(size: size, transition: animated ? .animated(duration: 0.3, curve: .spring) : .immediate)
        }
    }
    
    private func setupItems() {
        let startMonth = monthForDate(self.state.minDate)
        let endMonth = monthForDate(self.state.maxDate)
        let selectedMonth = monthForDate(self.state.selectedMonth)
                
        var currentIndex = 0
        
        var months: [Date] = [startMonth]
        var index = 1
        
        var nextMonth = startMonth
        while true {
            if let month = calendar.date(byAdding: .month, value: 1, to: nextMonth) {
                nextMonth = month
                if nextMonth == selectedMonth {
                    currentIndex = index
                }
                if nextMonth >= endMonth {
                    break
                } else {
                    months.append(nextMonth)
                }
                index += 1
            } else {
                break
            }
        }
        
        self.months = months
        self.currentIndex = currentIndex
    }
    
    public func updateTheme(_ theme: DatePickerTheme) {
        guard theme != self.theme else {
            return
        }
        self.theme = theme
                
        self.backgroundColor = self.theme.backgroundColor
        self.monthArrowNode.image = generateSmallArrowImage(color: theme.accentColor)
        self.previousButtonNode.setImage(generateNavigationArrowImage(color: theme.accentColor, mirror: true), for: .normal)
        self.nextButtonNode.setImage(generateNavigationArrowImage(color: theme.accentColor, mirror: false), for: .normal)
        
        for (_, monthNode) in self.monthNodes {
            monthNode.theme = theme
        }
        
        if let size = self.validLayout {
            self.updateLayout(size: size, transition: .immediate)
        }
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        guard let monthNode = self.monthNodes[self.months[self.currentIndex]] else {
            return
        }
        
        let location = recognizer.location(in: monthNode.view)
        if let day = monthNode.dateAtPoint(location) {
            let monthComponents = calendar.dateComponents([.month, .year], from: monthNode.month)
            var currentComponents = calendar.dateComponents([.hour, .minute, .day, .month, .year], from: self.date)

            currentComponents.year = monthComponents.year
            currentComponents.month = monthComponents.month
            currentComponents.day = Int(day)
            
            if let date = calendar.date(from: currentComponents), date >= self.minimumDate && date < self.maximumDate {
                let updatedState = State(minDate: self.state.minDate, maxDate: self.state.maxDate, date: date, displayingMonthSelection: self.state.displayingMonthSelection, selectedMonth: monthNode.month)
                self.updateState(updatedState, animated: false)
                
                self.valueUpdated?(date)
            }
        }
    }
    
    @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            self.view.window?.endEditing(true)
        case .changed:
            let translation = recognizer.translation(in: self.view)
            var transitionFraction = translation.x / self.bounds.width
            if self.currentIndex <= 0 {
                transitionFraction = min(0.0, transitionFraction)
            }
            if self.currentIndex >= self.months.count - 1 {
                transitionFraction = max(0.0, transitionFraction)
            }
            self.transitionFraction = transitionFraction
            if let size = self.validLayout {
                let topInset: CGFloat = 78.0 + 44.0
                let containerSize = CGSize(width: size.width, height: size.height - topInset)
                self.updateItems(size: containerSize, transition: .animated(duration: 0.3, curve: .spring))
            }
        case .cancelled, .ended:
            let velocity = recognizer.velocity(in: self.view)
            var directionIsToRight: Bool?
            if abs(velocity.x) > 10.0 {
                directionIsToRight = velocity.x < 0.0
            } else if abs(self.transitionFraction) > 0.5 {
                directionIsToRight = self.transitionFraction < 0.0
            }
            var updatedIndex = self.currentIndex
            if let directionIsToRight = directionIsToRight {
                if directionIsToRight {
                    updatedIndex = min(updatedIndex + 1, self.months.count - 1)
                } else {
                    updatedIndex = max(updatedIndex - 1, 0)
                }
            }
            self.currentIndex = updatedIndex
            self.transitionFraction = 0.0
            
            let updatedState = State(minDate: self.state.minDate, maxDate: self.state.maxDate, date: self.state.date, displayingMonthSelection: self.state.displayingMonthSelection, selectedMonth: self.months[updatedIndex])
            self.updateState(updatedState, animated: true)
        default:
            break
        }
    }
    
    private func updateItems(size: CGSize, update: Bool = false, transition: ContainedViewLayoutTransition) {
        var validIds: [Date] = []
        
        if self.currentIndex >= 0 && self.currentIndex < self.months.count {
            let preloadSpan: Int = 1
            for i in max(0, self.currentIndex - preloadSpan) ... min(self.currentIndex + preloadSpan, self.months.count - 1) {
                validIds.append(self.months[i])
                var itemNode: MonthNode?
                var wasAdded = false
                if let current = self.monthNodes[self.months[i]] {
                    itemNode = current
                    current.minimumDate = self.state.minDate
                    current.maximumDate = self.state.maxDate
                    current.date = self.state.date
                    current.updateLayout(size: size)
                } else {
                    wasAdded = true
                    let addedItemNode = MonthNode(theme: self.theme, month: self.months[i], minimumDate: self.state.minDate, maximumDate: self.state.maxDate, date: self.state.date)
                    itemNode = addedItemNode
                    self.monthNodes[self.months[i]] = addedItemNode
                    self.contentNode.addSubnode(addedItemNode)
                }
                if let itemNode = itemNode {
                    let indexOffset = CGFloat(i - self.currentIndex)
                    let itemFrame = CGRect(origin: CGPoint(x: indexOffset * size.width + self.transitionFraction * size.width, y: 0.0), size: size)
                    
                    if wasAdded {
                        itemNode.frame = itemFrame
                        itemNode.updateLayout(size: size)
                    } else {
                        transition.updateFrame(node: itemNode, frame: itemFrame)
                        itemNode.updateLayout(size: size)
                    }
                }
            }
        }
      
        var removeIds: [Date] = []
        for (id, _) in self.monthNodes {
            if !validIds.contains(id) {
                removeIds.append(id)
            }
        }
        for id in removeIds {
            if let itemNode = self.monthNodes.removeValue(forKey: id) {
                itemNode.removeFromSupernode()
            }
        }
    }
    
    public func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
    
        let timeHeight: CGFloat = 44.0
        let topInset: CGFloat = 78.0 + timeHeight
        let sideInset: CGFloat = 16.0
        
        let month = monthForDate(self.state.selectedMonth)
        let components = calendar.dateComponents([.month, .year], from: month)
        
        let timeTitleSize = self.timeTitleNode.updateLayout(size)
        self.timeTitleNode.frame = CGRect(origin: CGPoint(x: 16.0, y: 14.0), size: timeTitleSize)
        
        let timePickerSize = self.timePickerNode.updateLayout(size: size)
        self.timePickerNode.frame = CGRect(origin: CGPoint(x: size.width - timePickerSize.width - 16.0, y: 6.0), size: timePickerSize)
        self.timeSeparatorNode.frame = CGRect(x: 16.0, y: timeHeight, width: size.width - 16.0, height: UIScreenPixel)
        
        self.monthTextNode.attributedText = NSAttributedString(string: stringForMonth(strings: self.strings, month: components.month.flatMap { Int32($0) - 1 } ?? 0, ofYear: components.year.flatMap { Int32($0) - 1900 } ?? 100), font: controlFont, textColor: self.state.displayingMonthSelection ? self.theme.accentColor : self.theme.textColor)
        let monthSize = self.monthTextNode.updateLayout(size)
        
        let monthTextFrame = CGRect(x: sideInset, y: 11.0 + timeHeight, width: monthSize.width, height: monthSize.height)
        self.monthTextNode.frame = monthTextFrame
        
        let monthArrowFrame = CGRect(x: monthTextFrame.maxX + 10.0, y: monthTextFrame.minY + 4.0, width: 7.0, height: 12.0)
        self.monthArrowNode.position = monthArrowFrame.center
        self.monthArrowNode.bounds = CGRect(origin: CGPoint(), size: monthArrowFrame.size)
        
        transition.updateTransformRotation(node: self.monthArrowNode, angle: self.state.displayingMonthSelection ? CGFloat.pi / 2.0 : 0.0)
        
        self.monthButtonNode.frame = monthTextFrame.inset(by: UIEdgeInsets(top: -6.0, left: -6.0, bottom: -6.0, right: -30.0))
        
        self.previousButtonNode.isEnabled = self.currentIndex > 0
        self.previousButtonNode.frame = CGRect(x: size.width - sideInset - 54.0, y: monthTextFrame.minY + 1.0, width: 10.0, height: 17.0)
        self.nextButtonNode.isEnabled = self.currentIndex < self.months.count - 1
        self.nextButtonNode.frame = CGRect(x: size.width - sideInset - 13.0, y: monthTextFrame.minY + 1.0, width: 10.0, height: 17.0)

        let daysSideInset: CGFloat = 12.0
        let cellSize: CGFloat = floor((size.width - daysSideInset * 2.0) / 7.0)
        
        for i in 0 ..< self.dayNodes.count {
            let dayNode = self.dayNodes[i]
            dayNode.attributedText = NSAttributedString(string: shortStringForDayOfWeek(strings: self.strings, day: Int32(i)).uppercased(), font: dayFont, textColor: theme.secondaryTextColor)
            
            let textSize = dayNode.updateLayout(size)
            let cellFrame = CGRect(x: daysSideInset + CGFloat(i) * cellSize, y: topInset - 38.0, width: cellSize, height: cellSize)
            let textFrame = CGRect(origin: CGPoint(x: cellFrame.minX + floor((cellFrame.width - textSize.width) / 2.0), y: cellFrame.minY + floor((cellFrame.height - textSize.height) / 2.0)), size: textSize)
            
            dayNode.frame = textFrame
        }
        
        let containerSize = CGSize(width: size.width, height: size.height - topInset)
        self.contentNode.frame = CGRect(origin: CGPoint(x: 0.0, y: topInset), size: containerSize)
        
        self.updateItems(size: containerSize, transition: transition)
        
        self.pickerBackgroundNode.frame = CGRect(origin: CGPoint(), size: size)
        self.pickerBackgroundNode.isUserInteractionEnabled = self.state.displayingMonthSelection
        transition.updateAlpha(node: self.pickerBackgroundNode, alpha: self.state.displayingMonthSelection ? 1.0 : 0.0)
        
        self.pickerNode.frame = CGRect(x: sideInset, y: topInset, width: size.width - sideInset * 2.0, height: 180.0)
    }
    
    @objc private func monthButtonPressed() {
        let updatedState = State(minDate: self.state.minDate, maxDate: self.state.maxDate, date: self.state.date, displayingMonthSelection: !self.state.displayingMonthSelection, selectedMonth: self.state.selectedMonth)
        self.updateState(updatedState, animated: true)
    }
    
    @objc private func previousButtonPressed() {
        guard let month = calendar.date(byAdding: .month, value: -1, to: self.state.selectedMonth), let size = self.validLayout else {
            return
        }
            
        let updatedState = State(minDate: self.state.minDate, maxDate: self.state.maxDate, date: self.state.date, displayingMonthSelection: self.state.displayingMonthSelection, selectedMonth: month)
        self.updateState(updatedState, animated: false)
        
        self.contentNode.layer.animatePosition(from: CGPoint(x: -size.width, y: 0.0), to: CGPoint(), duration: 0.3, additive: true)
    }
    
    @objc private func nextButtonPressed() {
        guard let month = calendar.date(byAdding: .month, value: 1, to: self.state.selectedMonth), let size = self.validLayout else {
            return
        }
            
        let updatedState = State(minDate: self.state.minDate, maxDate: self.state.maxDate, date: self.state.date, displayingMonthSelection: self.state.displayingMonthSelection, selectedMonth: month)
        self.updateState(updatedState, animated: false)
        
        self.contentNode.layer.animatePosition(from: CGPoint(x: size.width, y: 0.0), to: CGPoint(), duration: 0.3, additive: true)
    }
}

private final class MonthPickerNode: ASDisplayNode, UIPickerViewDelegate, UIPickerViewDataSource {
    private let theme: DatePickerTheme
    private let strings: PresentationStrings
    
    var date: Date
    var yearRange: Range<Int> {
        didSet {
            self.reload()
        }
    }
    
    var minimumDate: Date?
    var maximumDate: Date?
    
    private let valueChanged: (Date) -> Void
    private let pickerView: UIPickerView
    
    init(theme: DatePickerTheme, strings: PresentationStrings, date: Date, yearRange: Range<Int>, valueChanged: @escaping (Date) -> Void) {
        self.theme = theme
        self.strings = strings
        
        self.date = date
        self.yearRange = yearRange
        
        self.valueChanged = valueChanged
        
        self.pickerView = UIPickerView()
        
        super.init()
        
        self.pickerView.delegate = self
        self.pickerView.dataSource = self
        self.view.addSubview(self.pickerView)
        
        self.reload()
    }
    
    private func reload() {
        self.pickerView.reloadAllComponents()
        
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)
        self.pickerView.selectRow(month - 1, inComponent: 0, animated: false)
        self.pickerView.selectRow(year - yearRange.startIndex, inComponent: 1, animated: false)
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: constrainedSize.width, height: 180.0)
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 2
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if component == 1 {
            return self.yearRange.count
        } else {
            return 12
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return 40.0
    }
    
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        let string: String
        if component == 1 {
            string = "\(self.yearRange.startIndex + row)"
        } else {
            string = stringForMonth(strings: self.strings, month: Int32(row))
        }
        return NSAttributedString(string: string, font: Font.medium(15.0), textColor: self.theme.textColor)
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let month = pickerView.selectedRow(inComponent: 0) + 1
        let year = self.yearRange.startIndex + pickerView.selectedRow(inComponent: 1)
        
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: self.date)
        let day = components.day ?? 1
        components.day = 1
        components.month = month
        components.year = year
        
        let tempDate = calendar.date(from: components)!
        let numberOfDays = calendar.range(of: .day, in: .month, for: tempDate)!.count
        components.day = min(day, numberOfDays)
        
        var date = calendar.date(from: components)!
        
        if let minimumDate = self.minimumDate, let maximumDate = self.maximumDate {
            var changed = false
            if date < minimumDate {
                date = minimumDate
                changed = true
            }
            if date > maximumDate {
                date = maximumDate
                changed = true
            }
            if changed {
                let month = calendar.component(.month, from: date)
                let year = calendar.component(.year, from: date)
                self.pickerView.selectRow(month - 1, inComponent: 0, animated: true)
                self.pickerView.selectRow(year - yearRange.startIndex, inComponent: 1, animated: true)
            }
        }
        
        self.date = date
        
        self.valueChanged(date)
    }
    
    override func layout() {
        super.layout()
        
        self.pickerView.frame = CGRect(origin: CGPoint(), size: CGSize(width: self.bounds.size.width, height: 180.0))
    }
}

private final class TimePickerNode: ASDisplayNode {
    private var theme: DatePickerTheme
    private let dateTimeFormat: PresentationDateTimeFormat
    
    private let backgroundNode: ASDisplayNode
    private let textNode: ImmediateTextNode
    private let amPMSelectorNode: SegmentedControlNode
    
    var date: Date
    var minDate: Date?
    var maxDate: Date?
    
    var valueChanged: ((Date) -> Void)?
    
    init(theme: DatePickerTheme, dateTimeFormat: PresentationDateTimeFormat, date: Date) {
        self.theme = theme
        self.dateTimeFormat = dateTimeFormat
        self.date = date
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = theme.segmentedControlTheme.backgroundColor
        self.backgroundNode.cornerRadius = 9.0
        
        self.textNode = ImmediateTextNode()
        
        let hours = calendar.component(.hour, from: date)
        
        self.amPMSelectorNode = SegmentedControlNode(theme: theme.segmentedControlTheme, items: [SegmentedControlItem(title: "AM"), SegmentedControlItem(title: "PM")], selectedIndex: hours > 12 ? 1 : 0)
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.amPMSelectorNode)
        
        self.amPMSelectorNode.selectedIndexChanged = { index in
            let hours = calendar.component(.hour, from: date)
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: self.date)
            if index == 0 && hours >= 12 {
                components.hour = hours - 12
            } else if index == 1 && hours < 12 {
                components.hour = hours + 12
            }
            if let newDate = calendar.date(from: components) {
                self.valueChanged?(newDate)
            }
        }
    }
    
    func updateTheme(_ theme: DatePickerTheme) {
        self.theme = theme
        
        self.backgroundNode.backgroundColor = theme.segmentedControlTheme.backgroundColor
    }
    
    func updateLayout(size: CGSize) -> CGSize {
        self.backgroundNode.frame = CGRect(x: 0.0, y: 0.0, width: 75.0, height: 36.0)
      
        var contentSize = CGSize()
        
        let hours = Int32(calendar.component(.hour, from: self.date))
        let minutes = Int32(calendar.component(.hour, from: self.date))
        let string = stringForShortTimestamp(hours: hours, minutes: minutes, dateTimeFormat: self.dateTimeFormat).replacingOccurrences(of: " AM", with: "").replacingOccurrences(of: " PM", with: "")
        
        self.textNode.attributedText = NSAttributedString(string: string, font: Font.with(size: 21.0, design: .regular, weight: .regular, traits: [.monospacedNumbers]), textColor: self.theme.textColor)
        let textSize = self.textNode.updateLayout(size)
        self.textNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((self.backgroundNode.frame.width - textSize.width) / 2.0), y: floorToScreenPixels((self.backgroundNode.frame.height - textSize.height) / 2.0)), size: textSize)
        
        if self.dateTimeFormat.timeFormat == .military {
            contentSize = self.backgroundNode.frame.size
            self.amPMSelectorNode.isHidden = true
        } else {
            self.amPMSelectorNode.isHidden = false
            let segmentedSize = self.amPMSelectorNode.updateLayout(.sizeToFit(maximumWidth: 120.0, minimumWidth: 80.0, height: 36.0), transition: .immediate)
            self.amPMSelectorNode.frame = CGRect(x: 85.0, y: 0.0, width: segmentedSize.width, height: 36.0)
            contentSize = CGSize(width: 85.0 + segmentedSize.width, height: 36.0)
        }
        
        return contentSize
    }
}
