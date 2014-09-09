//
//  ViewController.m
//  DHTIOS
//
//  Created by Andy on 8/9/14.
//  Copyright (c) 2014 Andy. All rights reserved.
//

#import "ViewController.h"
#import "DHT.h"

@interface ViewController ()
            

@end

@implementation ViewController
            
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    DHT *dht = [[DHT alloc] init];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
