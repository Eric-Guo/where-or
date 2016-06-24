# Where Or

[Where or](https://github.com/rails/rails/pull/16052) function backport from Rails 5 for Rails 4.2

Confirm works from Rails 4.2.3 to 4.2.6, including for preloading

[![Gem Version](https://badge.fury.io/rb/where-or.svg)](https://badge.fury.io/for/rb/where-or)

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