import 'package:flutter/painting.dart';

/// The colours of a chart through the day, from the theme (a record, so two are equal when their
/// colours are):
/// - `frame`, `grid`: the plot's background and its dashed hour lines;
/// - `band`, `bandEdge`: the normal range and its dashed edges;
/// - `range`, `line`, `outside`: an hour's lowest-to-highest bar, the line through the averages,
///   and an average's dot outside the normal range;
/// - `ring`: around each dot, so it stands out from the bar behind it;
/// - `picked`: the picked hour's column; `label`: the values at the left;
/// - `stripData`, `stripMissing`, `stripNotYet`: the strip under the plot.
typedef HistoryPlotColours = ({
  Color frame,
  Color grid,
  Color band,
  Color bandEdge,
  Color range,
  Color line,
  Color outside,
  Color ring,
  Color picked,
  Color label,
  Color stripData,
  Color stripMissing,
  Color stripNotYet,
});
