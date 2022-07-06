
close all; clear all; clc;
%% EDA 

abalone=importdata('abalone_original.csv');

% Missing data:
check_missing= sum(ismissing(abalone.data));
% No missing data 

% Basic statistics and table for numerical features:
Mean=mean(abalone.data)';
Min=min(abalone.data)';
Max=max(abalone.data)';
Std_dev=std(abalone.data)';

stats_table=table(Mean,Min,Max,Std_dev);
names=table({'length','diameter','height','whole-weight','shucked-weight','viscera-weight','shell-weight','rings'}');

stats=[names,stats_table]
stats.Properties.VariableNames{1} = 'Predictors';

% Removal of unsual entries observed in statistics table:
sexColumn=abalone.textdata(:,1);
heightColumn = abalone.data(:,3);

index=find(heightColumn==0,2,'first')
sexColumn(index);

abalone.data(1258,:)=[];
abalone.data(3997,:)=[];
abalone.textdata(1258,:)=[];
abalone.textdata(3997,:)=[];

% Statistics for Sex (Independent categorical Variable):
sex=abalone.textdata(:,1);

male=sum(count(sex,['M']));
female=sum(count(sex,['F']));
infants=sum(count(sex,['I']));

X = [male,female,infants];
labels = {'Males','Females','Infants'};
pie(X,labels);

% Creating a dummy variable for Sex:
sex=categorical(sex(2:4176));
D = dummyvar(sex);

% Statistics for Age (Dependent Variable):
rings=abalone.data(:,8);

hist(rings,29)
xlabel('Number of rings');
ylabel('Count');

% Creating New Age categories:
ordered=sort(rings);

young=ordered(1:1405,1);
adult=ordered(1406:3482,1);
old=ordered(3483:4175,1);

%Amount of entries in each array:
x=[1405,2077,693];
labels_age={'Young','Adult','Old'};
pie(x,labels_age);

% Assigning New Categories for Age:
for i=1:4175
    
    if rings(i,1)<=8
        rings(i,2) = 1;
    elseif rings(i,1)>=13
        rings(i,2)=3;
    else
        rings(i,2) = 2;
    end
end
new_rings=rings(:,2);

% Histograms for length parameters:
h1 = histogram(abalone.data(:,1));
hold on
h2 = histogram(abalone.data(:,2)');
hold on
h3 = histogram(abalone.data(:,3));
xlabel('in millimitres')
ylabel('Count');
legend({'Length','Diameter','Height'},'Location','northeast')
hold off

% Histograms for weight parameters:
h4 = histogram(abalone.data(:,4));
hold on
h5 = histogram(abalone.data(:,5));
hold on
h6 = histogram(abalone.data(:,6));
hold on
h7 = histogram(abalone.data(:,7));
xlabel('in grams')
ylabel('Count');
legend({'Whole Weight','Shucked Weight','Viscera Weight','Shell Weight'},'Location','northeast')
hold off

% Correlation matrix:
c=corrcoef(abalone.data);
xvalues={'length','diameter','height','whole-weight','shucked-weight','viscera-weight','shell-weight','rings'};
yvalues={'length','diameter','height','whole-weight','shucked-weight','viscera-weight','shell-weight','rings'};
h =heatmap(xvalues,yvalues,c,'Colormap',summer);
h.Title = 'Correlation Matrix';
h.ColorScaling = 'scaledcolumns';

% Data merging:
abalone_features=[abalone.data(:,1:7),D];

% Selected informative features:
%(code for feature importance selection is provided in appendix)
new_features=abalone_features(:,1:7);

% Final Dataset:
abalone_data=[new_features,new_rings];
new_abalone=array2table(abalone_data);
VarNames={'length','diameter','height','whole_weight','shucked_weight','viscera_weight','shell_weight','rings'};
new_abalone.Properties.VariableNames = VarNames;


%% Split into training and testing sets:
c = cvpartition(new_abalone.rings,'Holdout',0.1);
train_Data = new_abalone(training(c),:);
test_Data = new_abalone(test(c),:);

train_y=train_Data.rings;
train_X=train_Data(:,1:7);
train_X=table2array(train_X);

test_y=test_Data.rings;
test_X=test_Data(:,1:7);
test_X=table2array(test_X);

%% Decision Trees:
% cross-validation classification errors:
cv_err = zeros(1,100);
for i=1:100
    our_tree=fitctree(train_X,train_y,'MinLeafSize',i,'CrossVal','on');
    classErrorDefault = kfoldLoss(our_tree);
    cv_err(i)=classErrorDefault;
end

MaxSplit=uint32(1):uint32(100);
plot(MaxSplit,cv_err);
xlabel('Min Leaf Size');
ylabel('cross-validated error');
% This gives optimal model with leaf size around 30 and supported by 
% hyperparameter optimisation (appendix).
% For the purpose of this study, we will choose model with Leaf Size = 30.

% Optimal Decision Tree with cross validation:
optimal_DTcv=fitctree(train_X,train_y,'MinLeafSize',30,'CrossVal','on');

% Optimal Decision Tree wouthout cross validation:
optimal_DT=fitctree(train_X,train_y,'MinLeafSize',30);

% Prediction using the model:
predicted_y=predict(optimal_DT,test_X);

% Evaluation Metrics for Decision Trees:

% Training Loss:
train_loss=resubLoss(optimal_DT);

% Predicted Loss:
mse=sum((test_y-predicted_y).^2)/numel(test_y);

% Validation Loss:
cv_error = kfoldLoss(optimal_DTcv);

% Time:
tic
 optimal_DT=fitctree(train_X,train_y,'MinLeafSize',30);
timeElapsed = toc

% Confusion Matrix:
c=confusionmat(predicted_y,test_y);
confusionchart(c);

% Precision,specificity,sensitivity,accuracy,f1-score
stats_dt=statsOfMeasure(c,0);

%% Random Forests:
% Training using Out-of-Bag method:
our_forest=TreeBagger(100,new_abalone(:,1:7),new_abalone(:,8),'OOBPrediction','On');

figure;
oobErrorBaggedEnsemble = oobError(our_forest);   
plot(oobErrorBaggedEnsemble)
xlabel 'Number of grown trees';
ylabel 'Out-of-bag classification error';
obb_err=min(oobErrorBaggedEnsemble);
min_obb_index=find(oobErrorBaggedEnsemble==min(oobErrorBaggedEnsemble))

% Using out of bag method for training follows in line with optimisation
% of hyperparameters (appendix). The optimal model has around 90 trees.
%  For the purpose of this study, we will choose model with Tree Size = 88
% and Minimum Leaf Size = 5.

% Optimal Random Forest:
t = templateTree('Reproducible',true,'MinLeafSize',5); 
optimal_RF = fitcensemble(train_X,train_y,'Method','Bag','NumLearningCycles',88,'Learners',t);

% Prediction using the model:
predict_y=predict(optimal_RF,test_X);

% Evaluating Metrics for Random Forests:
%Training error:
train_err=resubLoss(optimal_RF);

%Testing error:
test_err=loss(optimal_RF,test_X,test_y);

% Cross valisation error:
cv_err=kfoldLoss(cv);

%Out-of-bag error:
obb_err=oobLoss(optimal_RF);

%Time:
tic
 t = templateTree('Reproducible',true); 
optimal_RF = fitcensemble(train_X,train_y,'Method','Bag','NumLearningCycles',88,'Learners',t);
timeElapsed = toc

%Confusion matrix:
cRf=confusionmat(predict_y,test_y);
confusionchart(cRf);

% Precision,specificity,sensitivity,accuracy,f1-score
stats_rf=statsOfMeasure(cRf,0);
