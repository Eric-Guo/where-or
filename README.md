# Where Or

[Where or](https://github.com/rails/rails/pull/16052) function backport from Rails 5 for Rails 4.2

[![Build Status](https://travis-ci.org/Eric-Guo/where-or.svg)](https://travis-ci.org/Eric-Guo/where-or) [![Code Climate](https://codeclimate.com/github/Eric-Guo/where-or.png)](https://codeclimate.com/github/Eric-Guo/where-or) [![Code Coverage](https://codeclimate.com/github/Eric-Guo/where-or/coverage.png)](https://codeclimate.com/github/Eric-Guo/where-or) [![Gem Version](https://badge.fury.io/rb/where-or.svg)](https://badge.fury.io/for/rb/where-or)

Installation:

``` ruby
gem 'where-or'
```

## Usage

```ruby
post = Post.where('id = 1').or(Post.where('id = 2'))
```


## Declare of original

Largely copy from [bf4 gist](https://gist.github.com/bf4/84cff9cc6ac8489d769e)