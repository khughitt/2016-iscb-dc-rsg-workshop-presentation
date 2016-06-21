#!/usr/bin/env Rscript
#
# Code to generate figures used in ISCB DC RSG 2016 workshop presentation
# Keith Hughitt
# June, 2016
#
# For the igraph SVG images generated, a final command-line Inkscape command
# was used to remove excess whitespace:
# 
# inkscape --verb=FitCanvasToDrawing --verb=FileSave --verb=FileClose example-network.svg
#
library('knitr')
library('igraph')
library('ggplot2')
library('gplots')
library('reshape2')
library('svglite')
library('dendextend')
library('dplyr')

set.seed(1)

###############################################################################
#
# Figure 1: Network representation (directed)
#
###############################################################################

# create a 5x5 binary matrix
adj <- matrix(sample(c(0,1), 25, replace=TRUE), nrow=5)

# set diagonal to zero (no self-loops)
diag(adj) <- 0

# create graph
g <- graph.adjacency(adj)

# generating the figure
svg(file='../image/example-network-directed.svg', bg='transparent')
plot(g)
dev.off()

# for separate edges in each direction
#plot(g, edge.curved=rep(0.5, ecount(g)))

###############################################################################
#
# Figure 2: Network representation (undirected)
#
###############################################################################

# convert to undirected network
adj[upper.tri(adj)] <- 0

# plotting with igraph
g <- graph.adjacency(adj, mode='undirected')

svg(file='../image/example-network-undirected.svg', bg='transparent')
plot(g)
dev.off()

###############################################################################
#
# Figure 3: Network representation (weighted)
#
###############################################################################

# create a weight adjacency matrix
adj <- matrix(rnorm(25, mean=3.5, sd=5), nrow=5)
adj[upper.tri(adj, diag=TRUE)] <- 0

# note that igraph ignores edges with negative weights
g <- graph.adjacency(adj, mode='undirected', weighted=TRUE)

svg(file='../image/example-network-undirected-weighted.svg', bg='transparent')
plot(g, edge.width=E(g)$weight)
dev.off()

###############################################################################
#
# Figures X-Y: Simulated data expression profiles
#
###############################################################################

# First, let's simulate expression profiles for 15 "genes" across 10
# time-points, including two clusters and a set some noise.
genes_per_cluster <- 15
num_timepoints <- 10

nvals <- genes_per_cluster * num_timepoints

# highly co-expressed cluster going from low->high expression
cluster1 <- matrix(rep(1:num_timepoints, genes_per_cluster) + 
                   rnorm(nvals, sd=0.5),
                   nrow=genes_per_cluster, byrow=TRUE)

# moderately co-expression cluster going from high->low expression
cluster2 <- matrix(rep(num_timepoints:1, genes_per_cluster) + 
                   rnorm(nvals, sd=1.0),
                   nrow=genes_per_cluster, byrow=TRUE)

# noise cluster (random expression)
noise <- matrix(sample(1:2, nvals, replace=TRUE) +
                rnorm(nvals, sd=1.5),
                nrow=genes_per_cluster, byrow=TRUE)

# combined dataset
expr <- rbind(cluster1, cluster2, noise)
colnames(expr) <- paste0('t', 1:num_timepoints)
rownames(expr) <- c(paste0('high_',  1:genes_per_cluster), 
                    paste0('low_',   1:genes_per_cluster),
                    paste0('noise_', 1:genes_per_cluster))

# Plot simulated expression profiles
df <- melt(expr, id.vars='row.names')
colnames(df) <- c('gene', 'time', 'expression')

# Add "type" column (high, low, noise)
df$type <- 'high'
df$type[grepl('low', df$gene)] <- 'low'
df$type[grepl('noise', df$gene)] <- 'noise'

# colors used for combined plot
# #00BA38 #619CFF #F8766D

# plot cluster 1
# theme_classic()
ggplot(df %>% filter(type=='high'), aes(x=time, y=expression, group=gene)) +
    geom_line(color='#F8766D') +
    ggtitle('Highly co-expressed genes') + 
    theme(plot.background=element_blank(),
          axis.text.x=element_text(angle=45, hjust=1))
ggsave('../image/expression-cluster1.svg', bg='transparent')

# plot cluster 2
ggplot(df %>% filter(type=='low'), aes(x=time, y=expression, group=gene)) +
    geom_line(color='#00BA38') +
    ggtitle('Moderately co-expressed genes') +
    theme(plot.background=element_blank(),
          axis.text.x=element_text(angle=45, hjust=1))
ggsave('../image/expression-cluster2.svg', bg='transparent')

# plot cluster 3
ggplot(df %>% filter(type=='noise'), aes(x=time, y=expression, group=gene)) +
    geom_line(color='#619CFF') +
    ggtitle('Non co-expressed genes') +
    theme(plot.background=element_blank(),
          axis.text.x=element_text(angle=45, hjust=1))
ggsave('../image/expression-cluster3.svg', bg='transparent')

# combined plot
ggplot(df, aes(x=time, y=expression, group=gene, color=type)) +
    geom_line() +
    ggtitle('All genes') +
    theme(plot.background=element_blank(),
          axis.text.x=element_text(angle=45, hjust=2))
ggsave('../image/expression-combined.svg', bg='transparent')


###############################################################################
#
# Figures : Correlation matrix / Hierarchical clustering dendrogram (Raw)
#
###############################################################################

# Create correlation matrix
cor_mat <- cor(t(expr))
adj_mat <- (cor_mat + 1) / 2

# Gene labels
gene_labels <- c(rep('high',  genes_per_cluster), 
                 rep('low',   genes_per_cluster),
                 rep('noise', genes_per_cluster))
gene_labels <- factor(gene_labels)

gene_colors <- c("#F8766D", "#00BA38", "#619CFF")[as.integer(gene_labels)]

# construct heatmap
png(file='../image/expression-heatmap-raw.png', bg='transparent', width=800, height=800)
h <- heatmap.2(cor_mat, ColSideColors=gene_colors, RowSideColors=gene_colors,
               margin=c(6, 6), revC=TRUE, xlab='Gene', ylab='Gene', trace='none',
               main="Correlation Matrix (Raw)")
dev.off()

###############################################################################
#
# Figure : Correlation matrix / Hierarchical clustering dendrogram
#          (power-transformation)
#
###############################################################################

# Shift from [-1,1] to [0,1] and raise to a power
pow_mat <- adj_mat**6

png(file='../image/expression-heatmap-power.png', bg='transparent', width=800, height=800)
heatmap.2(pow_mat, ColSideColors=gene_colors, RowSideColors=gene_colors,
          Rowv=h$rowInd, Colv=h$colInd,
          margin=c(6, 6), revC=TRUE, xlab='Gene', ylab='Gene', trace='none',
          main="Correlation Matrix (Power-transformed)")
dev.off()

###############################################################################
#
# Figures : Hierarchical clustering
#
###############################################################################

dissim_mat1 <- 1 - adj_mat
dissim_mat2 <- 1 - pow_mat

# label colors 
label_colors <- rep(c('#585fa1', '#a15860', '#60a158'),
                    each=genes_per_cluster)

# dendrogram based on raw (shifted) correlation matrix
dend1 <- dissim_mat1 %>% as.dist %>% hclust %>% as.dendrogram %>%
    set('labels_cex', 1)
dend1 <- dend1 %>% set('labels_col', label_colors[order.dendrogram(dend1)])

# hclust alone
svg(file='../image/hclust-raw.svg', bg='transparent', height=3, width=8.5,
    family='ubuntu')
plot(dend1)
dev.off()

# same thing but with cutoff and clusters displayed
clusters = cutree(dend1, h=0.65)

svg(file='../image/hclust-raw-clusters.svg', bg='transparent', height=3, 
    width=8.5, family='ubuntu')
plot(dend1, xlab="", sub="")
colored_bars(colors=clusters, dend=dend1, rowLabels='module')
abline(h=0.65, col='red', lty=2)
dev.off()

# dendrogram based on power-transformed (shifted) correlation matrix
dend2 <- dissim_mat2 %>% as.dist %>% hclust %>% as.dendrogram %>%
    set('labels_cex', 1)
dend2 <- dend2 %>% set('labels_col', label_colors[order.dendrogram(dend2)])

clusters = cutree(dend2, h=0.65)

svg(file='../image/hclust-power-transformed.svg', bg='transparent', height=3,
    width=8.5, family='ubuntu')
plot(dend2, xlab="", sub="")
colored_bars(colors=clusters, dend=dend2, rowLabels='module')
abline(h=0.65, col='red', lty=2)
dev.off()

