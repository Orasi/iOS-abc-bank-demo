//
//  ABCSettingsTableViewController.m
//  AbcBankDemo
//
//  Created by David Quach on 10/16/14.
//  Copyright (c) 2014 Orasi. All rights reserved.
//

#import "ABCSettingsTableViewController.h"
#import "ABCURLData.h"

@interface ABCSettingsTableViewController ()

<UIAlertViewDelegate>

@property (nonatomic, strong) NSMutableArray *settings;
@property (nonatomic, strong) UISwitch *backendSwitch;
@property (nonatomic, strong) UITableViewCell *customURLCell;
@property (nonatomic) NSURLSession *session;
@property (nonatomic, strong) NSMutableArray *json;

@end

@implementation ABCSettingsTableViewController

// Constructs the properties for the switch, cell, and session, then calls getUsers to find all the users
- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
        
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        _session = [NSURLSession sessionWithConfiguration:config delegate:nil delegateQueue:nil];
        
    }
    return self;
}

// Creates the first section of the table
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _backendSwitch = [[UISwitch alloc] init];
    
    _customURLCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"UITableViewCustomURLCell"];
    _customURLCell.selectionStyle = UITableViewCellSelectionStyleNone;
    _customURLCell.userInteractionEnabled = NO;
    _customURLCell.textLabel.enabled = NO;
    
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    _settings = [[NSMutableArray alloc] init];
    
    NSArray *backendSettings = @[@"Use Custom Backend", @"Set Backend URL"];
    NSDictionary *backendDict = @{@"settings": backendSettings};
    
    [self.settings addObject:backendDict];
    
    [self getUsers];
}

// Function to enable selection on the custom backend row
- (void)customBackend
{
    if (self.backendSwitch.isOn) {
        self.customURLCell.selectionStyle = UITableViewCellSelectionStyleDefault;
        self.customURLCell.userInteractionEnabled = YES;
        self.customURLCell.textLabel.enabled = YES;
        
    } else {
        self.customURLCell.selectionStyle = UITableViewCellSelectionStyleNone;
        self.customURLCell.userInteractionEnabled = NO;
        self.customURLCell.textLabel.enabled = NO;
    }
}

// Method to pull the json of the users and add the array to the settings property
- (void)getUsers
{
    NSURL *URL = [[ABCURLData storedURL] URL];
    NSString *requestURL = [[NSString alloc] initWithFormat:@"%@users.json", URL];
    NSURL *url = [[NSURL alloc] initWithString:requestURL];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url];
    NSURLSessionDataTask *dataTask = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if ([httpResponse statusCode] == 404) {
            UIAlertView *toast = [[UIAlertView alloc] initWithTitle:nil message:@"Please check URL\nformat is http://<domain name>/" delegate:self cancelButtonTitle:nil otherButtonTitles:nil, nil];
            [toast show];
            int duration = 3;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [toast dismissWithClickedButtonIndex:0 animated:YES];
            });
            
            [[ABCURLData storedURL] defaultURL];
            return;
        }
        _json = [[NSMutableArray alloc] initWithArray:[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]];

        if ([self.settings count] > 1) {
            [self.settings removeObjectAtIndex:1];
        }
        
        NSDictionary *usersDict = @{@"settings": self.json};
        [self.settings addObject:usersDict];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
        });
    }];
    
    [dataTask resume];
}

// Returns the number of rows in a section
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSDictionary *dictionary = self.settings[section];
    NSArray *array = dictionary[@"settings"];
    return [array count];
}

// creates the styles for the rows and fills in the data
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            UITableViewCell *backendCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"UITableViewCell"];
            backendCell.selectionStyle = UITableViewCellSelectionStyleNone;
            backendCell.textLabel.text = @"Use Custom Backend";
            backendCell.accessoryView = _backendSwitch;
            [self.backendSwitch addTarget:self action:@selector(customBackend) forControlEvents:UIControlEventValueChanged];
            
            return backendCell;
        } else {
            self.customURLCell.textLabel.text = @"Set Custom Backend URL";
            return self.customURLCell;
        }
    } else {
        UITableViewCell *usersCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"UITableViewCellUser"];
        NSDictionary *dictionary = self.settings[indexPath.section];
        NSArray *array = dictionary[@"settings"];
        usersCell.textLabel.text = [(NSDictionary *)array[indexPath.row] objectForKey:@"username"] ;
        return usersCell;
    }
}

// Makes the users section deletable
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 1) {
        return YES;
    } else {
        return NO;
    }
}

// When delete button is pressed the app will make a delete request to the server
// for the user and deletes the user from the json
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSURL *URL = [[ABCURLData storedURL] URL];
        NSDictionary *userID = (NSDictionary *)[self.json objectAtIndex:indexPath.row];
        NSString *message = [NSString stringWithFormat:@"%@users/%@", URL, [userID objectForKey:@"id"]];
        NSURL *url = [[NSURL alloc] initWithString:message];
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
        [request setHTTPMethod:@"delete"];
        [NSURLConnection connectionWithRequest:request delegate:self];
        [self.json removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0 && indexPath.row == 1) {
        UIAlertView *customURLAlert = [[UIAlertView alloc] initWithTitle:nil message:@"Enter URL for Custom Backend:" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Set", nil];
        customURLAlert.alertViewStyle = UIAlertViewStylePlainTextInput;
        UITextField *alertText = [customURLAlert textFieldAtIndex:0];
        alertText.text = [[[ABCURLData storedURL] URL] absoluteString];
        [customURLAlert show];
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 1) {
        UITextField *urlField = [alertView textFieldAtIndex:0];
        [ABCURLData storedURL].URL = [NSURL URLWithString:urlField.text];
        [self getUsers];
    }
}

// Returns the number of sections in the tableview
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    
    return [self.settings count];
}

// Creates the title for each section
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 0) {
        return @"Backend URL";
    } else {
        return @"Reset Users";
    }
    
}

// Creates the footer for the first section of the table
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section == 0) {
        NSURL *URL = [[ABCURLData storedURL] URL];
        NSString *message = [[NSString alloc] initWithFormat:@"Current backend URL: \n%@", URL];
        return message;
    } else {
        return @"";
    }
    
}

@end
