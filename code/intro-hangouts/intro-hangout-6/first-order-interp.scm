(load "pmatch.scm")

(define-syntax test
  (syntax-rules ()
    [(test name expr expected-val)
     (let ((v expr))
       (if (equal? v expected-val)
           (begin
             (display "passed test ")
             (write name)
             (newline))
           (error 'name
                  (format "\nTest ~s failed!!\nExpected ~s, but got ~s"
                          name
                          expected-val
                          v))))]))


(define empty-env
  '(empty-env))

(define lookup
  (lambda (y env^)
    (pmatch env^
            ((empty-env)
             (error 'lookup (format "unbound variable ~s" y)))
            ((ext-env ,x ,val ,env)
             (if (eq? x y)
                 val
                 (lookup y env)))
            ((letrec-env ,bindings ,env)
             (pmatch (assq y bindings)
                     [(,h . (half-closure ,h-x ,h-body))
                      `(closure ,h-x ,h-body ,env^)]
                     [#f (lookup y env)])))))

(define eval-expr
  (lambda (expr env)
    (pmatch expr
            [,b (guard (boolean? b))
                b]
            [,n (guard (number? n))
                n]
            [(zero? ,e)
             (zero? (eval-expr e env))]
            [(negative? ,e)
             (negative? (eval-expr e env))]
            [(add1 ,e)
             (add1 (eval-expr e env))]
            [(sub1 ,e)
             (sub1 (eval-expr e env))]
            [(- ,e)
             (- (eval-expr e env))]
            [(* ,e1 ,e2)
             (* (eval-expr e1 env) (eval-expr e2 env))]
            [(if ,e1 ,e2 ,e3)
             (if (eval-expr e1 env)
                 (eval-expr e2 env)
                 (eval-expr e3 env))]
            [,x (guard (symbol? x)) ; variable
                (lookup x env)]
            [(lambda (,x) ,body) (guard (symbol? x)) ; lambda/abstraction
             `(closure ,x ,body ,env)]
            [(letrec ,bindings ,letrec-body)
             (guard (legal-letrec-bindings? bindings))
             (let (prepare (lambda (binding)
                             (pmatch binding
                                     [(,f (lambda (,f-x) ,f-body))
                                      `(,f . (half-closure ,f-x ,f-body))])))
               (eval-expr letrec-body
                          `(letrec-env ,(map prepare bindings) ,env)))]
            [(,rator ,rand) ;application
             (apply-proc (eval-expr rator env) (eval-expr rand env))]
            [,else (error 'eval-expr
                          (format "unknown expression type: ~s\n"
                                  expr))])))

(define legal-letrec-bindings?
  (lambda (bindings)
    (and (list? bindings)
         (andmap
          (lambda (binding)
            (pmatch binding
                    [(,f (lambda (,f-x) ,f-body))
                     #t]
                    [,else #f]))
          bindings))))

(define apply-proc
  (lambda (proc val)
    (pmatch proc
            [(closure ,x ,body ,env)
             (eval-expr body `(ext-env ,x ,val ,env))])))

(test "! 5"
      (eval-expr '(((lambda (!)
                      (lambda (n)
                        ((! !) n)))
                    (lambda (!)
                      (lambda (n)
                        (if (zero? n)
                            1
                            (* n ((! !) (sub1 n)))))))
                   5)
                 empty-env)
      120)

(test "eval-expr lambda"
      (eval-expr '(lambda (y) (* y y)) `(ext-env z 17 ,empty-env))
      '(closure y (* y y) (ext-env z 17 (empty-env))))

(test "eval-expr app  1"
      (eval-expr '((lambda (y) (* y y)) (add1 5)) `(ext-env z 17 ,empty-env))
      36)

(test "eval-expr app  2"
      (eval-expr '(((lambda (y)
                      (lambda (z)
                        (* y z)))
                    (add1 4))
                   (sub1 7))
                 empty-env)
      30)

(test "eval-expr var"
      (eval-expr 'y `(ext-env y 5 ,empty-env))
      5)

(test "eval-expr var/add1"
      (eval-expr '(add1 y) `(ext-env y 5 ,empty-env))
      6)

(test "eval-expr num"
      (eval-expr '5 empty-env)
      5)

(test "eval-expr bignum"
      (eval-expr '5983724897985749873827589372589732985798237598273598 empty-env)
      5983724897985749873827589372589732985798237598273598)

(test "eval-expr zero?   1"
      (eval-expr '(zero? 0) empty-env)
      #t)

(test "eval-expr zero?   2"
      (eval-expr '(zero? 1) empty-env)
      #f)

(test "eval-expr zero?   3"
      (eval-expr '(zero? (add1 0)) empty-env)
      #f)

(test "eval-expr zero?   4"
      (eval-expr '(zero? (sub1 1)) empty-env)
      #t)

(test "eval-expr add1"
      (eval-expr '(add1 (add1 5)) empty-env)
      7)

(test "eval-expr sub1"
      (eval-expr '(sub1 (sub1 5)) empty-env)
      3)

(test "eval-expr *  1"
      (eval-expr '(* 3 4) empty-env)
      12)

(test "eval-expr *  2"
      (eval-expr '(* (* 3 4) 5) empty-env)
      60)

(test "eval-expr *  3"
      (eval-expr '(* 5 (* 3 4)) empty-env)
      60)

(test "eval-expr if  1"
      (eval-expr '(if (zero? 0) 5 6) empty-env)
      5)

(test "eval-expr if  2"
      (eval-expr '(if (zero? 1) 5 6) empty-env)
      6)

(test "eval-expr if  3"
      (eval-expr '(if (zero? (* 3 4)) (add1 6) (sub1 6)) empty-env)
      5)

(test "eval-expr letrec even? 6"
      (eval-expr '(letrec ((even? (lambda (n)
                                    (if (zero? n)
                                        #t
                                        (odd? (sub1 n)))))
                           (odd? (lambda (n)
                                   (if (zero? n)
                                       #f
                                       (even? (sub1 n))))))
                    (even? 6))
                 empty-env)
      #t)

(test "eval-expr letrec even? 5"
      (eval-expr '(letrec ((even? (lambda (n)
                                    (if (zero? n)
                                        #t
                                        (odd? (sub1 n)))))
                           (odd? (lambda (n)
                                   (if (zero? n)
                                       #f
                                       (even? (sub1 n))))))
                    (even? 5))
                 empty-env)
      #f)

(test "eval-expr letrec even? negative 5"
      (eval-expr '(letrec ((even? (lambda (n)
                                    (if (negative? n)
                                        ((negative n) even?)
                                        (if (zero? n)
                                            #t
                                            (odd? (sub1 n))))))
                           (odd? (lambda (n)
                                   (if (negative? n)
                                       ((negative n) odd?)
                                       (if (zero? n)
                                           #f
                                           (even? (sub1 n))))))
                           (negative (lambda (n)
                                       (lambda (f)
                                         (f (- n))))))
                    (even? -5))
                 empty-env)
      #f)

(test "eval-expr letrec even? negative 6"
      (eval-expr '(letrec ((even? (lambda (n)
                                    (if (negative? n)
                                        ((negative n) even?)
                                        (if (zero? n)
                                            #t
                                            (odd? (sub1 n))))))
                           (odd? (lambda (n)
                                   (if (negative? n)
                                       ((negative n) odd?)
                                       (if (zero? n)
                                           #f
                                           (even? (sub1 n))))))
                           (negative (lambda (n)
                                       (lambda (f)
                                         (f (- n))))))
                    (even? -6))
                 empty-env)
      #t)

(test "eval-expr letrec no bindings"
      (eval-expr '(letrec ()
                    3)
                 empty-env)
      3)

(test "eval-expr letrec one binding"
      (eval-expr '(letrec ((fact (lambda (x)
                                   (if (zero? x)
                                       1
                                       (* x (fact (sub1 x)))))))
                    (fact 5))
                 empty-env)
      120)
