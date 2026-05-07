#import "@preview/ilm:2.0.0": *

#set page("a4")

#set text(lang: "en")

#show: ilm.with(
  title: [\_],
  authors: "_",
  date: datetime(year: 2024, month: 03, day: 19),
  abstract: [\_],
  table-of-contents: none
)

