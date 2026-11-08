const minCardWidth = 280.0;
const cardGap = 16.0;
const maxColumns = 5;
const cardHeight = 388.0;

/// How many repo cards fit side by side: at most five, fewer as the window narrows.
int columnsFor(double width) => ((width + cardGap) / (minCardWidth + cardGap)).floor().clamp(1, maxColumns);
