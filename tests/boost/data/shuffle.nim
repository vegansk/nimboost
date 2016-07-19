proc shuffle[T](xs: var openarray[T]) =
  for i in countup(1, xs.len - 1):
    let j = random(succ i)
    swap(xs[i], xs[j])
    
